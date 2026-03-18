import SwiftUI

/// A drop-in SwiftUI toggle for enabling/disabling iCloud sync.
///
/// ```swift
/// Section("Data & Sync") {
///     CloudSyncToggle(manager: syncManager)
/// }
/// ```
public struct CloudSyncToggle: View {
    @ObservedObject var manager: CloudSyncManager
    @State private var isToggling = false

    public init(manager: CloudSyncManager) {
        self.manager = manager
    }

    public var body: some View {
        Toggle("iCloud Sync", isOn: Binding(
            get: { manager.isSyncEnabled },
            set: { newValue in
                guard !isToggling else { return }
                isToggling = true
                Task {
                    defer { isToggling = false }
                    try? await manager.setSyncEnabled(newValue)
                }
            }
        ))
        .disabled(isToggling)

        if isToggling {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text(manager.isSyncEnabled ? "Disabling sync..." : "Enabling sync...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
