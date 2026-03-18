import CloudKit
import CoreData
import Foundation

/// The main entry point for CloudSyncKit.
///
/// `CloudSyncManager` wraps `NSPersistentCloudKitContainer` and provides:
/// - Safe Core Data contexts that guard store readiness
/// - Real-time sync status monitoring
/// - Full sync toggle (enable/disable without app restart)
/// - Per-entity conflict resolution
/// - Completion-based force sync
/// - Generic duplicate cleaning
///
/// ## Quick Start
/// ```swift
/// // Minimal setup
/// let sync = CloudSyncManager(containerName: "MyApp")
///
/// // Full setup with per-entity conflict resolution
/// let sync = CloudSyncManager(configuration: .init(
///     containerName: "MyApp",
///     cloudKitContainerIdentifier: "iCloud.com.myteam.myapp",
///     entityConflictStrategies: [
///         "UserProgress": MaxValueStrategy(maxFields: ["score", "level"]),
///         "Settings": LatestTimestampStrategy()
///     ]
/// ))
///
/// // In your SwiftUI App
/// @main struct MyApp: App {
///     @StateObject private var sync = CloudSyncManager(containerName: "MyApp")
///
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .environment(\.managedObjectContext, sync.rawViewContext)
///                 .environmentObject(sync)
///         }
///     }
/// }
/// ```
@MainActor
public final class CloudSyncManager: ObservableObject {

    // MARK: - Published State

    /// Current sync status.
    @Published public private(set) var syncStatus: SyncStatus = .unknown

    /// Whether iCloud sync is currently enabled.
    @Published public private(set) var isSyncEnabled: Bool

    /// Timestamp of the last successful sync.
    @Published public private(set) var lastSyncDate: Date?

    /// Recent sync events for debugging.
    @Published public private(set) var recentEvents: [SyncEvent] = []

    // MARK: - Core Data Access

    /// The underlying `NSPersistentCloudKitContainer`. Use for advanced operations.
    public var container: NSPersistentCloudKitContainer { storeCoordinator.container }

    /// The raw view context for `@Environment(\.managedObjectContext)`.
    public var rawViewContext: NSManagedObjectContext { storeCoordinator.viewContext }

    /// Save-safe view context.
    public var viewContext: SafeManagedObjectContext {
        SafeManagedObjectContext(context: storeCoordinator.viewContext)
    }

    /// Context provider for creating background contexts.
    public private(set) lazy var contexts = ContextProvider(storeCoordinator: storeCoordinator)

    /// Duplicate cleaner instance.
    public let duplicateCleaner = DuplicateCleaner()

    // MARK: - Internal Components

    private let configuration: CloudSyncConfiguration
    private let storeCoordinator: StoreCoordinator
    private let eventMonitor: SyncEventMonitor
    private let toggleController: SyncToggleController

    // MARK: - Initialization

    /// Create a manager with full configuration.
    public init(configuration: CloudSyncConfiguration) {
        self.configuration = configuration
        self.storeCoordinator = StoreCoordinator(configuration: configuration)
        self.eventMonitor = SyncEventMonitor(maxEventLogSize: configuration.maxEventLogSize)
        self.toggleController = SyncToggleController(
            storeCoordinator: storeCoordinator,
            syncEnabledKey: configuration.syncEnabledKey
        )

        // Set initial state
        toggleController.setInitialPreferenceIfNeeded(defaultEnabled: configuration.enableSyncByDefault)
        self.isSyncEnabled = toggleController.isSyncEnabled

        // Start loading
        Task { await self.initialize() }
    }

    /// Convenience: create a manager with just a container name. Server-wins merge policy, sync enabled by default.
    public convenience init(containerName: String) {
        self.init(configuration: CloudSyncConfiguration(containerName: containerName))
    }

    /// Convenience: create a manager with container name and CloudKit identifier.
    public convenience init(containerName: String, cloudKitContainerIdentifier: String) {
        self.init(configuration: CloudSyncConfiguration(
            containerName: containerName,
            cloudKitContainerIdentifier: cloudKitContainerIdentifier
        ))
    }

    // MARK: - Public API

    /// Whether the persistent store is loaded and ready for operations.
    public var isStoreReady: Bool { storeCoordinator.isStoreLoaded }

    /// Wait until the store is loaded. Call this before any Core Data operation during app startup.
    public func waitForStoreReady() async {
        while !storeCoordinator.isStoreLoaded {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }

    /// Enable or disable iCloud sync. Performs a full store teardown/rebuild.
    public func setSyncEnabled(_ enabled: Bool) async throws {
        syncStatus = .syncing(.setup)

        do {
            if enabled {
                // Check account availability first
                let accountStatus = await toggleController.checkAccountStatus()
                guard accountStatus == .available else {
                    syncStatus = accountStatus
                    return
                }
                try await toggleController.enableSync()
                eventMonitor.startMonitoring()
                syncStatus = .available
            } else {
                eventMonitor.stopMonitoring()
                try await toggleController.disableSync()
                syncStatus = .disabled
            }
            isSyncEnabled = enabled
        } catch {
            syncStatus = .error(.underlying(error.localizedDescription))
            throw error
        }
    }

    /// Trigger an immediate sync and wait for completion.
    public func forceSync() async throws -> SyncResult {
        guard isSyncEnabled else {
            throw SyncError.underlying("Sync is disabled")
        }

        syncStatus = .syncing(.exporting)

        let operation = ForceSyncOperation(
            storeCoordinator: storeCoordinator,
            eventMonitor: eventMonitor,
            timeout: configuration.forceSyncTimeout
        )

        let result = try await operation.execute()

        if result.success {
            syncStatus = .available
        }

        return result
    }

    /// Save the view context safely. No-op if store isn't ready.
    @discardableResult
    public func save() -> Bool {
        viewContext.trySave()
    }

    /// Save or throw.
    public func saveOrThrow() throws {
        try viewContext.safeSave()
    }

    /// Get counts of all entities in the store. Useful for debugging and sync verification.
    public func entityCounts() async -> [String: Int] {
        guard isStoreReady else { return [:] }

        let context = storeCoordinator.newBackgroundContext()
        return await context.perform {
            var counts: [String: Int] = [:]
            guard let entities = context.persistentStoreCoordinator?.managedObjectModel.entities else {
                return counts
            }
            for entity in entities {
                guard let name = entity.name else { continue }
                let request = NSFetchRequest<NSManagedObject>(entityName: name)
                counts[name] = (try? context.count(for: request)) ?? 0
            }
            return counts
        }
    }

    // MARK: - Private

    private func initialize() async {
        do {
            try await storeCoordinator.loadStores(cloudKitEnabled: isSyncEnabled)

            if isSyncEnabled {
                eventMonitor.startMonitoring()
                let accountStatus = await toggleController.checkAccountStatus()
                syncStatus = accountStatus
            } else {
                syncStatus = .disabled
            }

            // Bind event monitor updates to our published properties
            observeEventMonitor()
        } catch {
            syncStatus = .error(.underlying(error.localizedDescription))
        }
    }

    private func observeEventMonitor() {
        // Forward event monitor state to our published properties
        Task { @MainActor [weak self] in
            guard let self else { return }
            // Use a simple polling approach since we're already @MainActor
            // In production, you'd use Combine publishers
            while !Task.isCancelled {
                self.recentEvents = self.eventMonitor.recentEvents
                if let date = self.eventMonitor.lastSyncDate {
                    self.lastSyncDate = date
                }
                if self.isSyncEnabled && self.eventMonitor.currentStatus != .unknown {
                    self.syncStatus = self.eventMonitor.currentStatus
                }
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            }
        }
    }
}
