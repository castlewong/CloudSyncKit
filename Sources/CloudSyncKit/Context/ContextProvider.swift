import CoreData
import Foundation

/// Factory for creating safe managed object contexts.
///
/// Provides both view (main queue) and background contexts,
/// all wrapped in `SafeManagedObjectContext` for save safety.
public final class ContextProvider {

    private let storeCoordinator: StoreCoordinator

    init(storeCoordinator: StoreCoordinator) {
        self.storeCoordinator = storeCoordinator
    }

    /// The main-queue context for UI work. Save-safe.
    public var viewContext: SafeManagedObjectContext {
        SafeManagedObjectContext(context: storeCoordinator.viewContext)
    }

    /// The raw `NSManagedObjectContext` for SwiftUI's `@Environment(\.managedObjectContext)`.
    /// Use `viewContext` when you need save safety.
    public var rawViewContext: NSManagedObjectContext {
        storeCoordinator.viewContext
    }

    /// Create a new background context. Save-safe.
    public func newBackgroundContext() -> SafeManagedObjectContext {
        SafeManagedObjectContext(context: storeCoordinator.newBackgroundContext())
    }

    /// Whether the persistent store is loaded and ready.
    public var isStoreReady: Bool {
        storeCoordinator.isStoreLoaded
    }
}
