import CoreData
import Foundation

/// All configuration options for CloudSyncKit.
/// Pass this to `CloudSyncManager.init(configuration:)` to customize behavior.
public struct CloudSyncConfiguration {

    /// The Core Data model name (the .xcdatamodeld file name without extension).
    public let containerName: String

    /// The CloudKit container identifier (e.g. "iCloud.com.myteam.myapp").
    /// If nil, uses the default container.
    public let cloudKitContainerIdentifier: String?

    /// Default merge policy applied to all entities unless overridden.
    /// Defaults to `.mergeByPropertyStoreTrump` (server-wins).
    public let defaultMergePolicy: NSMergePolicy

    /// Per-entity conflict resolution strategies. Key is the entity name.
    public let entityConflictStrategies: [String: ConflictResolutionStrategy]

    /// UserDefaults key for the iCloud sync toggle state.
    public let syncEnabledKey: String

    /// Whether iCloud sync is enabled on first launch. Defaults to `true`.
    public let enableSyncByDefault: Bool

    /// Whether contexts automatically merge parent changes. Defaults to `true`.
    public let automaticallyMergesChangesFromParent: Bool

    /// Maximum number of sync events to keep in memory. Defaults to 50.
    public let maxEventLogSize: Int

    /// Timeout in seconds for force sync operations. Defaults to 30.
    public let forceSyncTimeout: TimeInterval

    public init(
        containerName: String,
        cloudKitContainerIdentifier: String? = nil,
        defaultMergePolicy: NSMergePolicy = .mergeByPropertyStoreTrump,
        entityConflictStrategies: [String: ConflictResolutionStrategy] = [:],
        syncEnabledKey: String = "CloudSyncKit_iCloudSyncEnabled",
        enableSyncByDefault: Bool = true,
        automaticallyMergesChangesFromParent: Bool = true,
        maxEventLogSize: Int = 50,
        forceSyncTimeout: TimeInterval = 30
    ) {
        self.containerName = containerName
        self.cloudKitContainerIdentifier = cloudKitContainerIdentifier
        self.defaultMergePolicy = defaultMergePolicy
        self.entityConflictStrategies = entityConflictStrategies
        self.syncEnabledKey = syncEnabledKey
        self.enableSyncByDefault = enableSyncByDefault
        self.automaticallyMergesChangesFromParent = automaticallyMergesChangesFromParent
        self.maxEventLogSize = maxEventLogSize
        self.forceSyncTimeout = forceSyncTimeout
    }
}
