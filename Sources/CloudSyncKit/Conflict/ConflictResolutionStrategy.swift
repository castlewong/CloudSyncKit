import CoreData
import Foundation

/// Protocol for pluggable per-entity conflict resolution.
///
/// Implement this to control how conflicts are resolved when the same record
/// is modified both locally and on another device via CloudKit.
public protocol ConflictResolutionStrategy {
    /// Resolve a conflict between local and server values.
    ///
    /// - Parameters:
    ///   - localObject: The local `NSManagedObject` involved in the conflict.
    ///   - serverValues: The property values from the server version.
    ///   - conflictingKeys: The property names that differ.
    /// - Returns: A dictionary of property names → values that should be persisted.
    func resolve(
        localObject: NSManagedObject,
        serverValues: [String: Any],
        conflictingKeys: Set<String>
    ) -> [String: Any]
}
