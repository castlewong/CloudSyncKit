import CoreData
import Foundation

extension NSManagedObjectContext {

    /// Save only if the persistent store is loaded and there are changes.
    /// A convenience for code that doesn't use `SafeManagedObjectContext`.
    ///
    /// ```swift
    /// try context.cloudSyncSafeSave()
    /// ```
    public func cloudSyncSafeSave() throws {
        guard let stores = persistentStoreCoordinator?.persistentStores,
              !stores.isEmpty else {
            throw SyncError.storeNotReady
        }
        guard hasChanges else { return }
        try save()
    }

    /// Save silently. Returns `true` on success, logs a warning and returns `false` on failure.
    @discardableResult
    public func cloudSyncTrySave() -> Bool {
        guard let stores = persistentStoreCoordinator?.persistentStores,
              !stores.isEmpty else {
            print("⚠️ CloudSyncKit: Skipping save — persistent store not ready")
            return false
        }
        guard hasChanges else { return true }
        do {
            try save()
            return true
        } catch {
            print("❌ CloudSyncKit: Save failed — \(error.localizedDescription)")
            return false
        }
    }
}
