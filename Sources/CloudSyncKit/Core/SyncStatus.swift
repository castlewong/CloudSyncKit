import CloudKit
import CoreData
import Foundation

/// The current state of iCloud sync.
public enum SyncStatus: Equatable, Sendable {
    case unknown
    case notSignedIn
    case available
    case syncing(SyncOperation)
    case disabled
    case error(SyncError)

    public enum SyncOperation: String, Sendable {
        case setup = "Setting up"
        case importing = "Importing"
        case exporting = "Exporting"
    }

    /// Whether sync is in a working state (available or actively syncing).
    public var isOperational: Bool {
        switch self {
        case .available, .syncing: return true
        default: return false
        }
    }

    public var localizedDescription: String {
        switch self {
        case .unknown: return "Checking..."
        case .notSignedIn: return "Not signed in to iCloud"
        case .available: return "Available"
        case .syncing(let op): return op.rawValue
        case .disabled: return "Disabled"
        case .error(let err): return err.localizedDescription
        }
    }
}

/// Errors specific to CloudSyncKit.
public enum SyncError: LocalizedError, Equatable, Sendable {
    case notAuthenticated
    case networkUnavailable
    case quotaExceeded
    case rateLimited
    case storeNotReady
    case containerMismatch(String)
    case underlying(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not signed in to iCloud"
        case .networkUnavailable: return "No network connection"
        case .quotaExceeded: return "iCloud storage full"
        case .rateLimited: return "Too many requests — try again later"
        case .storeNotReady: return "Data store not ready"
        case .containerMismatch(let msg): return "Container error: \(msg)"
        case .underlying(let msg): return msg
        }
    }
}

/// A recorded sync event from CloudKit.
public struct SyncEvent: Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let type: EventType
    public let succeeded: Bool
    public let errorMessage: String?

    public enum EventType: String, Sendable {
        case setup = "Setup"
        case importing = "Import"
        case exporting = "Export"
        case unknown = "Unknown"
    }

    public init(id: UUID = UUID(), date: Date = Date(), type: EventType, succeeded: Bool, errorMessage: String? = nil) {
        self.id = id
        self.date = date
        self.type = type
        self.succeeded = succeeded
        self.errorMessage = errorMessage
    }
}

/// Result of a force sync operation.
public struct SyncResult: Sendable {
    public let success: Bool
    public let events: [SyncEvent]
    public let duration: TimeInterval

    public init(success: Bool, events: [SyncEvent] = [], duration: TimeInterval = 0) {
        self.success = success
        self.events = events
        self.duration = duration
    }
}
