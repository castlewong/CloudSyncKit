import CloudKit
import CoreData
import Foundation

/// Handles the full enable/disable of CloudKit sync without requiring an app restart.
///
/// This is what Nichijou's `reinitializeContainerWithCloudKit()` should have been:
/// it tears down the persistent store and reloads with or without CloudKit options.
final class SyncToggleController {

    private let storeCoordinator: StoreCoordinator
    private let syncEnabledKey: String

    init(storeCoordinator: StoreCoordinator, syncEnabledKey: String) {
        self.storeCoordinator = storeCoordinator
        self.syncEnabledKey = syncEnabledKey
    }

    /// Whether sync is currently enabled (persisted in UserDefaults).
    var isSyncEnabled: Bool {
        UserDefaults.standard.bool(forKey: syncEnabledKey)
    }

    /// Set up the initial preference on first launch.
    func setInitialPreferenceIfNeeded(defaultEnabled: Bool) {
        let hasSetKey = "\(syncEnabledKey)_initialized"
        guard !UserDefaults.standard.bool(forKey: hasSetKey) else { return }
        UserDefaults.standard.set(defaultEnabled, forKey: syncEnabledKey)
        UserDefaults.standard.set(true, forKey: hasSetKey)
    }

    /// Enable CloudKit sync. Tears down local-only store and rebuilds with CloudKit.
    func enableSync() async throws {
        UserDefaults.standard.set(true, forKey: syncEnabledKey)
        try await storeCoordinator.reloadStores(cloudKitEnabled: true)
    }

    /// Disable CloudKit sync. Tears down CloudKit store and rebuilds local-only.
    /// All local data is preserved through the swap.
    func disableSync() async throws {
        UserDefaults.standard.set(false, forKey: syncEnabledKey)
        try await storeCoordinator.reloadStores(cloudKitEnabled: false)
    }

    /// Check if iCloud account is available.
    func checkAccountStatus() async -> SyncStatus {
        await withCheckedContinuation { continuation in
            CKContainer.default().accountStatus { status, error in
                if let error {
                    let ckError = error as? CKError
                    switch ckError?.code {
                    case .networkUnavailable, .networkFailure:
                        continuation.resume(returning: .error(.networkUnavailable))
                    case .notAuthenticated:
                        continuation.resume(returning: .notSignedIn)
                    case .quotaExceeded:
                        continuation.resume(returning: .error(.quotaExceeded))
                    case .requestRateLimited:
                        continuation.resume(returning: .error(.rateLimited))
                    default:
                        continuation.resume(returning: .error(.underlying(error.localizedDescription)))
                    }
                    return
                }

                switch status {
                case .available:
                    continuation.resume(returning: .available)
                case .noAccount:
                    continuation.resume(returning: .notSignedIn)
                case .restricted:
                    continuation.resume(returning: .error(.underlying("iCloud account restricted")))
                case .couldNotDetermine:
                    continuation.resume(returning: .unknown)
                case .temporarilyUnavailable:
                    continuation.resume(returning: .error(.underlying("iCloud temporarily unavailable")))
                @unknown default:
                    continuation.resume(returning: .unknown)
                }
            }
        }
    }
}
