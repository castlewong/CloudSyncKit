import CoreData
import Foundation

/// Performs a force sync operation with completion monitoring and timeout.
///
/// Unlike Nichijou's fire-and-forget approach with a 3-second delay,
/// this actually monitors CloudKit events to know when sync completes.
final class ForceSyncOperation {

    private let storeCoordinator: StoreCoordinator
    private let eventMonitor: SyncEventMonitor
    private let timeout: TimeInterval

    init(storeCoordinator: StoreCoordinator, eventMonitor: SyncEventMonitor, timeout: TimeInterval) {
        self.storeCoordinator = storeCoordinator
        self.eventMonitor = eventMonitor
        self.timeout = timeout
    }

    /// Execute a force sync and wait for completion or timeout.
    @MainActor
    func execute() async throws -> SyncResult {
        let startTime = Date()

        guard storeCoordinator.isStoreLoaded else {
            throw SyncError.storeNotReady
        }

        // Save current context to trigger CloudKit export
        let viewContext = storeCoordinator.viewContext
        if viewContext.hasChanges {
            try viewContext.save()
        }

        // Trigger background save to push any pending changes
        let bgContext = storeCoordinator.newBackgroundContext()
        try await bgContext.perform {
            if bgContext.hasChanges {
                try bgContext.save()
            }
        }

        // Wait for CloudKit to process
        let event = await eventMonitor.awaitNextEvent(timeout: timeout)

        let duration = Date().timeIntervalSince(startTime)

        if let event {
            return SyncResult(
                success: event.succeeded,
                events: [event],
                duration: duration
            )
        } else {
            // Timeout — no event received, but sync may still be in progress
            return SyncResult(
                success: false,
                events: [],
                duration: duration
            )
        }
    }
}
