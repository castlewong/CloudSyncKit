import CoreData
import Foundation

/// A save-safe wrapper around `NSManagedObjectContext`.
///
/// Guarantees that saves only happen when the persistent store is loaded.
/// Eliminates the need to scatter `guard persistentStores.isEmpty` checks across your codebase.
///
/// ```swift
/// let safe = SafeManagedObjectContext(context: manager.viewContext)
/// try safe.safeSave()  // no-op if store isn't ready, throws if actual save fails
/// ```
public final class SafeManagedObjectContext {

    /// The underlying Core Data context. Use this when framework APIs require `NSManagedObjectContext`.
    public let underlying: NSManagedObjectContext

    public init(context: NSManagedObjectContext) {
        self.underlying = context
    }

    /// Whether the persistent store is loaded and ready for writes.
    public var isStoreReady: Bool {
        guard let stores = underlying.persistentStoreCoordinator?.persistentStores else {
            return false
        }
        return !stores.isEmpty
    }

    /// Save only if the persistent store is loaded and there are unsaved changes.
    ///
    /// - Throws: `SyncError.storeNotReady` if stores aren't loaded.
    ///           Core Data errors if the actual save fails.
    public func safeSave() throws {
        guard isStoreReady else {
            throw SyncError.storeNotReady
        }
        guard underlying.hasChanges else { return }
        try underlying.save()
    }

    /// Save silently — logs a warning if the store isn't ready, but doesn't throw.
    /// Returns `true` if save succeeded, `false` otherwise.
    @discardableResult
    public func trySave() -> Bool {
        guard isStoreReady else {
            print("⚠️ CloudSyncKit: Skipping save — persistent store not ready")
            return false
        }
        guard underlying.hasChanges else { return true }
        do {
            try underlying.save()
            return true
        } catch {
            print("❌ CloudSyncKit: Save failed — \(error.localizedDescription)")
            return false
        }
    }

    /// Perform a block on this context and auto-save if it succeeds.
    public func performAndSave(_ block: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        try await underlying.perform { [underlying] in
            try block(underlying)
        }
        try safeSave()
    }
}
