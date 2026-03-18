import CoreData
import Foundation

/// Observes `NSPersistentCloudKitContainer` sync events and maintains an event log.
///
/// Publishes status updates and provides an event history for debugging.
@MainActor
final class SyncEventMonitor: ObservableObject {

    @Published private(set) var currentStatus: SyncStatus = .unknown
    @Published private(set) var recentEvents: [SyncEvent] = []
    @Published private(set) var lastSyncDate: Date?

    private let maxEventLogSize: Int
    private var observer: NSObjectProtocol?

    /// Continuation for consumers awaiting sync completion (used by force sync).
    private var syncCompletionContinuations: [UUID: CheckedContinuation<SyncEvent, Never>] = [:]

    init(maxEventLogSize: Int) {
        self.maxEventLogSize = maxEventLogSize
    }

    func startMonitoring() {
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleEvent(notification)
            }
        }
    }

    func stopMonitoring() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    /// Wait for the next sync event of a given type to complete.
    /// Used internally by force sync to know when the operation finishes.
    func awaitNextEvent(timeout: TimeInterval) async -> SyncEvent? {
        let id = UUID()

        return await withTaskGroup(of: SyncEvent?.self) { group in
            // Task 1: Wait for the event
            group.addTask { @MainActor in
                await withCheckedContinuation { continuation in
                    self.syncCompletionContinuations[id] = continuation
                }
            }

            // Task 2: Timeout
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }

            // Return whichever finishes first
            let result = await group.next() ?? nil

            // Clean up
            group.cancelAll()
            await MainActor.run {
                self.syncCompletionContinuations.removeValue(forKey: id)
            }

            return result
        }
    }

    // MARK: - Private

    private func handleEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else {
            return
        }

        let eventType: SyncEvent.EventType
        switch event.type {
        case .setup: eventType = .setup
        case .import: eventType = .importing
        case .export: eventType = .exporting
        @unknown default: eventType = .unknown
        }

        let syncEvent = SyncEvent(
            type: eventType,
            succeeded: event.succeeded,
            errorMessage: event.error?.localizedDescription
        )

        // Update event log
        recentEvents.insert(syncEvent, at: 0)
        if recentEvents.count > maxEventLogSize {
            recentEvents = Array(recentEvents.prefix(maxEventLogSize))
        }

        // Update status
        if event.endDate == nil {
            // Event still in progress
            currentStatus = .syncing(eventType.toSyncOperation)
        } else if event.succeeded {
            currentStatus = .available
            lastSyncDate = Date()
        } else if let error = event.error {
            currentStatus = .error(.underlying(error.localizedDescription))
        }

        // Notify any force sync waiters
        if event.endDate != nil {
            for (id, continuation) in syncCompletionContinuations {
                continuation.resume(returning: syncEvent)
                syncCompletionContinuations.removeValue(forKey: id)
            }
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

extension SyncEvent.EventType {
    var toSyncOperation: SyncStatus.SyncOperation {
        switch self {
        case .setup: return .setup
        case .importing: return .importing
        case .exporting: return .exporting
        case .unknown: return .setup
        }
    }
}
