import CoreData
import Foundation

/// Always use server/remote values. This is the safest default for CloudKit
/// since the server is the source of truth.
public struct ServerWinsStrategy: ConflictResolutionStrategy {
    public init() {}

    public func resolve(
        localObject: NSManagedObject,
        serverValues: [String: Any],
        conflictingKeys: Set<String>
    ) -> [String: Any] {
        serverValues
    }
}

/// Always use local values. Use with caution — can silently drop remote changes.
public struct LocalWinsStrategy: ConflictResolutionStrategy {
    public init() {}

    public func resolve(
        localObject: NSManagedObject,
        serverValues: [String: Any],
        conflictingKeys: Set<String>
    ) -> [String: Any] {
        var result: [String: Any] = [:]
        for key in conflictingKeys {
            if let value = localObject.value(forKey: key) {
                result[key] = value
            }
        }
        return result
    }
}

/// Keep whichever version has the most recent timestamp.
/// Falls back to server-wins if timestamps are equal or missing.
public struct LatestTimestampStrategy: ConflictResolutionStrategy {
    public let timestampKey: String

    public init(timestampKey: String = "updatedAt") {
        self.timestampKey = timestampKey
    }

    public func resolve(
        localObject: NSManagedObject,
        serverValues: [String: Any],
        conflictingKeys: Set<String>
    ) -> [String: Any] {
        let localDate = localObject.value(forKey: timestampKey) as? Date
        let serverDate = serverValues[timestampKey] as? Date

        switch (localDate, serverDate) {
        case let (local?, server?) where local > server:
            // Local is newer — keep local values
            var result: [String: Any] = [:]
            for key in conflictingKeys {
                if let value = localObject.value(forKey: key) {
                    result[key] = value
                }
            }
            return result
        default:
            // Server is newer or timestamps missing — server wins
            return serverValues
        }
    }
}

/// For progress-tracking entities: keep the highest value for specified fields,
/// fall back to another strategy for all other fields.
///
/// Perfect for SRS data where you never want to lose progress:
/// ```swift
/// MaxValueStrategy(
///     maxFields: ["correctStreak", "totalReviews", "masteryScore"],
///     fallback: ServerWinsStrategy()
/// )
/// ```
public struct MaxValueStrategy: ConflictResolutionStrategy {
    public let maxFields: Set<String>
    public let fallback: ConflictResolutionStrategy

    public init(maxFields: Set<String>, fallback: ConflictResolutionStrategy = ServerWinsStrategy()) {
        self.maxFields = maxFields
        self.fallback = fallback
    }

    public func resolve(
        localObject: NSManagedObject,
        serverValues: [String: Any],
        conflictingKeys: Set<String>
    ) -> [String: Any] {
        // Get fallback resolution for non-max fields
        let nonMaxKeys = conflictingKeys.subtracting(maxFields)
        var result = fallback.resolve(
            localObject: localObject,
            serverValues: serverValues,
            conflictingKeys: nonMaxKeys
        )

        // For max fields, keep whichever is higher
        for key in conflictingKeys.intersection(maxFields) {
            let localValue = localObject.value(forKey: key)
            let serverValue = serverValues[key]

            switch (localValue, serverValue) {
            case let (local as Int64, server as Int64):
                result[key] = max(local, server)
            case let (local as Int32, server as Int32):
                result[key] = max(local, server)
            case let (local as Int16, server as Int16):
                result[key] = max(local, server)
            case let (local as Double, server as Double):
                result[key] = max(local, server)
            case let (local as Float, server as Float):
                result[key] = max(local, server)
            default:
                // Can't compare — fall back to server
                if let sv = serverValue {
                    result[key] = sv
                }
            }
        }

        return result
    }
}

/// For SRS-specific data: keep the minimum ease factor (harder = safer)
/// and maximum streaks/reviews.
///
/// Designed for spaced repetition systems where losing progress is worse
/// than repeating a review.
public struct SRSMergeStrategy: ConflictResolutionStrategy {
    public let minFields: Set<String>
    public let maxFields: Set<String>

    /// - Parameters:
    ///   - minFields: Fields where the lower value wins (e.g. "easeFactor").
    ///   - maxFields: Fields where the higher value wins (e.g. "correctStreak", "totalReviews").
    public init(minFields: Set<String> = ["easeFactor"], maxFields: Set<String> = ["correctStreak", "totalReviews"]) {
        self.minFields = minFields
        self.maxFields = maxFields
    }

    public func resolve(
        localObject: NSManagedObject,
        serverValues: [String: Any],
        conflictingKeys: Set<String>
    ) -> [String: Any] {
        var result: [String: Any] = [:]

        for key in conflictingKeys {
            let localValue = localObject.value(forKey: key)
            let serverValue = serverValues[key]

            if minFields.contains(key) {
                result[key] = pickMin(localValue, serverValue) ?? serverValue
            } else if maxFields.contains(key) {
                result[key] = pickMax(localValue, serverValue) ?? serverValue
            } else {
                // Default: server wins for unspecified fields
                if let sv = serverValue {
                    result[key] = sv
                }
            }
        }

        return result
    }

    private func pickMin(_ a: Any?, _ b: Any?) -> Any? {
        switch (a, b) {
        case let (a as Double, b as Double): return min(a, b)
        case let (a as Float, b as Float): return min(a, b)
        case let (a as Int64, b as Int64): return min(a, b)
        default: return nil
        }
    }

    private func pickMax(_ a: Any?, _ b: Any?) -> Any? {
        switch (a, b) {
        case let (a as Double, b as Double): return max(a, b)
        case let (a as Float, b as Float): return max(a, b)
        case let (a as Int64, b as Int64): return max(a, b)
        default: return nil
        }
    }
}
