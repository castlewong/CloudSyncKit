import CloudKit
import CoreData
import Foundation

/// Manages the `NSPersistentCloudKitContainer` lifecycle: loading, unloading, and swapping stores.
final class StoreCoordinator {

    let container: NSPersistentCloudKitContainer
    private let configuration: CloudSyncConfiguration
    private(set) var isStoreLoaded = false

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(configuration: CloudSyncConfiguration) {
        self.configuration = configuration
        self.container = NSPersistentCloudKitContainer(name: configuration.containerName)
    }

    /// Load persistent stores with CloudKit enabled or disabled based on configuration.
    func loadStores(cloudKitEnabled: Bool) async throws {
        let storeDescription = container.persistentStoreDescriptions.first
            ?? NSPersistentStoreDescription()

        // History tracking — required for CloudKit sync
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        if cloudKitEnabled {
            if let identifier = configuration.cloudKitContainerIdentifier {
                storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: identifier
                )
            }
            // If no explicit identifier, NSPersistentCloudKitContainer uses the default container
        } else {
            storeDescription.cloudKitContainerOptions = nil
        }

        container.persistentStoreDescriptions = [storeDescription]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { [weak self] _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    self?.isStoreLoaded = true
                    self?.configureViewContext()
                    continuation.resume()
                }
            }
        }
    }

    /// Tear down the current persistent store and reload with new CloudKit setting.
    /// Preserves all local data through the swap.
    func reloadStores(cloudKitEnabled: Bool) async throws {
        // Remove existing stores
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
        isStoreLoaded = false

        // Reload with new configuration
        try await loadStores(cloudKitEnabled: cloudKitEnabled)
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = configuration.defaultMergePolicy
        context.automaticallyMergesChangesFromParent = configuration.automaticallyMergesChangesFromParent
        return context
    }

    // MARK: - Private

    private func configureViewContext() {
        let ctx = container.viewContext
        ctx.automaticallyMergesChangesFromParent = configuration.automaticallyMergesChangesFromParent

        if !configuration.entityConflictStrategies.isEmpty {
            ctx.mergePolicy = EntityConflictRouter(
                defaultPolicy: configuration.defaultMergePolicy,
                entityStrategies: configuration.entityConflictStrategies
            )
        } else {
            ctx.mergePolicy = configuration.defaultMergePolicy
        }
    }
}
