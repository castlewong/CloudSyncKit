import CoreData
import Foundation

/// Strategy for deciding which duplicate to keep.
public struct DuplicateKeepStrategy<T: NSManagedObject> {

    /// Comparison function. Returns `true` if the first object should be kept over the second.
    public let compare: (T, T) -> Bool

    public init(compare: @escaping (T, T) -> Bool) {
        self.compare = compare
    }

    /// Keep the object with the highest value for a given key path.
    public static func keepHighest<V: Comparable>(_ keyPath: KeyPath<T, V>) -> DuplicateKeepStrategy<T> {
        DuplicateKeepStrategy { a, b in
            a[keyPath: keyPath] > b[keyPath: keyPath]
        }
    }

    /// Keep the object with the most recent date.
    public static func keepMostRecent(_ dateKeyPath: KeyPath<T, Date?>) -> DuplicateKeepStrategy<T> {
        DuplicateKeepStrategy { a, b in
            guard let dateA = a[keyPath: dateKeyPath] else { return false }
            guard let dateB = b[keyPath: dateKeyPath] else { return true }
            return dateA > dateB
        }
    }

    /// Keep the object with the highest value for a given key (accessed via KVC).
    /// Useful when the attribute is on a Core Data entity without a Swift property.
    public static func keepHighestValue(forKey key: String) -> DuplicateKeepStrategy<T> {
        DuplicateKeepStrategy { a, b in
            let valA = (a.value(forKey: key) as? Int64) ?? 0
            let valB = (b.value(forKey: key) as? Int64) ?? 0
            return valA > valB
        }
    }
}

/// Result of a duplicate cleaning operation.
public struct DuplicateCleanResult: Sendable {
    public let groupsProcessed: Int
    public let duplicatesFound: Int
    public let duplicatesRemoved: Int
}

/// Generic duplicate detection and cleanup for Core Data entities.
///
/// Example usage:
/// ```swift
/// let result = try await cleaner.clean(
///     entityType: KanaProgress.self,
///     groupBy: \.character,
///     keepStrategy: .keepHighestValue(forKey: "totalReviews"),
///     in: context
/// )
/// print("Removed \(result.duplicatesRemoved) duplicates")
/// ```
public final class DuplicateCleaner {

    public init() {}

    /// Find and remove duplicates for a given entity type.
    ///
    /// - Parameters:
    ///   - entityType: The `NSManagedObject` subclass to check.
    ///   - groupBy: A key path to the property used for grouping (objects with the same value are considered duplicates).
    ///   - keepStrategy: How to decide which duplicate to keep.
    ///   - context: The managed object context to operate on.
    /// - Returns: A `DuplicateCleanResult` with stats about what was cleaned.
    public func clean<T: NSManagedObject>(
        entityType: T.Type,
        groupBy keyPath: KeyPath<T, String?>,
        keepStrategy: DuplicateKeepStrategy<T>,
        in context: NSManagedObjectContext
    ) async throws -> DuplicateCleanResult {
        try await context.perform {
            let request = T.fetchRequest() as! NSFetchRequest<T>
            let allObjects = try context.fetch(request)

            // Group by the key
            var groups: [String: [T]] = [:]
            for object in allObjects {
                guard let key = object[keyPath: keyPath] else { continue }
                groups[key, default: []].append(object)
            }

            var totalDuplicatesFound = 0
            var totalRemoved = 0
            var groupsProcessed = 0

            for (_, objects) in groups where objects.count > 1 {
                groupsProcessed += 1
                totalDuplicatesFound += objects.count - 1

                // Sort using keep strategy — first element is the keeper
                let sorted = objects.sorted { keepStrategy.compare($0, $1) }
                let toDelete = sorted.dropFirst()

                for object in toDelete {
                    context.delete(object)
                    totalRemoved += 1
                }
            }

            if context.hasChanges {
                try context.save()
            }

            return DuplicateCleanResult(
                groupsProcessed: groupsProcessed,
                duplicatesFound: totalDuplicatesFound,
                duplicatesRemoved: totalRemoved
            )
        }
    }
}
