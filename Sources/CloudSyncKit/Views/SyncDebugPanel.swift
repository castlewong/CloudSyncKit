import SwiftUI

/// A full debug panel for iCloud sync diagnostics.
///
/// Shows: status, last sync time, entity counts, recent events, force sync button.
/// Drop this into your Settings view for instant debugging capabilities.
///
/// ```swift
/// Section("Sync Debug") {
///     SyncDebugPanel(manager: syncManager)
/// }
/// ```
public struct SyncDebugPanel: View {
    @ObservedObject var manager: CloudSyncManager
    @State private var entityCounts: [String: Int] = [:]
    @State private var isForceSyncing = false
    @State private var isLoadingCounts = false
    @State private var forceSyncResult: SyncResult?

    public init(manager: CloudSyncManager) {
        self.manager = manager
    }

    public var body: some View {
        // Force Sync
        Button {
            isForceSyncing = true
            Task {
                defer { isForceSyncing = false }
                forceSyncResult = try? await manager.forceSync()
            }
        } label: {
            HStack {
                if isForceSyncing {
                    ProgressView()
                        .controlSize(.small)
                    Text("Syncing...")
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Force Sync")
                }
            }
        }
        .disabled(isForceSyncing || !manager.isSyncEnabled)

        // Last sync
        if let date = manager.lastSyncDate {
            HStack {
                Text("Last Sync")
                Spacer()
                Text(date, style: .relative)
                    .foregroundStyle(.secondary)
            }
        }

        // Entity Counts
        Button {
            isLoadingCounts = true
            Task {
                entityCounts = await manager.entityCounts()
                isLoadingCounts = false
            }
        } label: {
            HStack {
                Image(systemName: "number.circle")
                Text("Show Data Counts")
            }
        }
        .disabled(isLoadingCounts)

        if !entityCounts.isEmpty {
            ForEach(entityCounts.sorted(by: { $0.key < $1.key }), id: \.key) { name, count in
                HStack {
                    Text(name)
                        .font(.caption)
                    Spacer()
                    Text("\(count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }

        // Recent Events
        if !manager.recentEvents.isEmpty {
            DisclosureGroup("Recent Events (\(manager.recentEvents.count))") {
                ForEach(manager.recentEvents.prefix(10)) { event in
                    HStack {
                        Circle()
                            .fill(event.succeeded ? Color.green : Color.red)
                            .frame(width: 6, height: 6)
                        Text(event.type.rawValue)
                            .font(.caption)
                        Spacer()
                        Text(event.date, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        // Force Sync Result
        if let result = forceSyncResult {
            HStack {
                Image(systemName: result.success ? "checkmark.circle" : "xmark.circle")
                    .foregroundStyle(result.success ? .green : .red)
                Text(result.success ? "Sync completed" : "Sync incomplete")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.1fs", result.duration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
