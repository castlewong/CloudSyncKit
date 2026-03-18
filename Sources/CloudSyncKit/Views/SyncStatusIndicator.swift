import SwiftUI

/// Displays the current iCloud sync status with color coding.
///
/// Supports three display styles:
/// - `.badge`: Colored circle only
/// - `.label`: Text label with color
/// - `.compact`: Circle + short text
///
/// ```swift
/// SyncStatusIndicator(manager: syncManager, style: .label)
/// ```
public struct SyncStatusIndicator: View {
    @ObservedObject var manager: CloudSyncManager

    public enum Style {
        case badge, label, compact
    }

    let style: Style

    public init(manager: CloudSyncManager, style: Style = .label) {
        self.manager = manager
        self.style = style
    }

    public var body: some View {
        switch style {
        case .badge:
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
        case .label:
            HStack {
                Text("Status")
                Spacer()
                Text(manager.syncStatus.localizedDescription)
                    .foregroundStyle(statusColor)
            }
        case .compact:
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(manager.syncStatus.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
        }
    }

    private var statusColor: Color {
        switch manager.syncStatus {
        case .available:
            return .green
        case .syncing:
            return .blue
        case .notSignedIn:
            return .orange
        case .disabled:
            return .gray
        case .error:
            return .red
        case .unknown:
            return .gray
        }
    }
}
