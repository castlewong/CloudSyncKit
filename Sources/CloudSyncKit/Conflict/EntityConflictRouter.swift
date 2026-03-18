import CoreData
import Foundation

/// A custom `NSMergePolicy` subclass that routes merge conflicts to per-entity strategies.
///
/// This is the core technical piece that enables different conflict resolution per entity.
/// Install it on a `NSManagedObjectContext.mergePolicy` and it will intercept all merge conflicts,
/// inspect the entity name, and dispatch to the registered strategy.
final class EntityConflictRouter: NSMergePolicy {

    private let entityStrategies: [String: ConflictResolutionStrategy]
    private let defaultPolicy: NSMergePolicy

    /// - Parameters:
    ///   - defaultPolicy: The fallback policy for entities without a registered strategy.
    ///   - entityStrategies: A mapping of entity name → `ConflictResolutionStrategy`.
    init(defaultPolicy: NSMergePolicy, entityStrategies: [String: ConflictResolutionStrategy]) {
        self.entityStrategies = entityStrategies
        self.defaultPolicy = defaultPolicy
        super.init(merge: defaultPolicy.mergeType)
    }

    override func resolve(mergeConflicts list: [Any]) throws {
        // Separate conflicts that have custom strategies from those that don't
        var customConflicts: [NSMergeConflict] = []
        var defaultConflicts: [Any] = []

        for item in list {
            guard let conflict = item as? NSMergeConflict,
                  let entityName = conflict.sourceObject.entity.name,
                  let strategy = entityStrategies[entityName] else {
                defaultConflicts.append(item)
                continue
            }

            // Apply custom strategy
            let serverValues = conflict.persistedSnapshot ?? conflict.objectSnapshot ?? [:]
            let localValues = conflict.objectSnapshot ?? [:]

            let conflictingKeys = Set(serverValues.keys).union(Set(localValues.keys))

            let resolved = strategy.resolve(
                localObject: conflict.sourceObject,
                serverValues: serverValues,
                conflictingKeys: conflictingKeys
            )

            // Apply resolved values to the object
            for (key, value) in resolved {
                conflict.sourceObject.setValue(value, forKey: key)
            }

            customConflicts.append(conflict)
        }

        // Let the default policy handle the rest
        if !defaultConflicts.isEmpty {
            try defaultPolicy.resolve(mergeConflicts: defaultConflicts)
        }

        // For custom-resolved conflicts, we still need to mark them as resolved
        // by calling super with the default policy behavior
        if !customConflicts.isEmpty {
            try super.resolve(mergeConflicts: customConflicts as [Any])
        }
    }
}
