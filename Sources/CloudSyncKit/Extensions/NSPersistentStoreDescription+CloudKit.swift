import CoreData
import Foundation

extension NSPersistentStoreDescription {

    /// Apply all required options for CloudKit sync.
    func applyCloudKitDefaults() {
        setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    }

    /// Remove CloudKit container options, making this a local-only store.
    func removeCloudKitOptions() {
        cloudKitContainerOptions = nil
    }
}
