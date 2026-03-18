# CloudSyncKit

A production-ready Swift Package for iCloud + Core Data sync in SwiftUI apps.

**Server-wins by default. Save-safe by design. Per-entity conflict resolution.**

## Why

Apple's `NSPersistentCloudKitContainer` is powerful but has sharp edges:
- Default merge policy silently drops remote changes
- Disabling sync requires an app restart
- No per-entity conflict resolution
- Save operations crash if called before the store loads
- Force sync has no completion callback

CloudSyncKit wraps all of this into a clean, safe API.

## Quick Start

```swift
import CloudSyncKit

@main
struct MyApp: App {
    @StateObject private var sync = CloudSyncManager(containerName: "MyApp")

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, sync.rawViewContext)
                .environmentObject(sync)
        }
    }
}
```

## Full Setup with Conflict Resolution

```swift
let sync = CloudSyncManager(configuration: .init(
    containerName: "MyApp",
    cloudKitContainerIdentifier: "iCloud.com.myteam.myapp",
    entityConflictStrategies: [
        // SRS data: keep highest streak, most reviews, lowest ease factor
        "WordProgress": SRSMergeStrategy(
            minFields: ["easeFactor"],
            maxFields: ["correctStreak", "totalReviews"]
        ),
        // Settings: whoever edited last wins
        "AppSettings": LatestTimestampStrategy(timestampKey: "updatedAt"),
        // Everything else: server wins (default)
    ]
))
```

## Drop-in SwiftUI Views

```swift
// In your Settings view
Section("Data & Sync") {
    CloudSyncToggle(manager: syncManager)       // Toggle + progress
    SyncStatusIndicator(manager: syncManager)    // Color-coded status
    SyncDebugPanel(manager: syncManager)         // Force sync, counts, events
}
```

## Features

### Safe Saves
Every save checks that the persistent store is loaded. No more crashes during app startup.

```swift
// Option 1: Safe context wrapper
try syncManager.viewContext.safeSave()

// Option 2: Silent save (logs warning on failure)
syncManager.save()

// Option 3: Extension on any context
try context.cloudSyncSafeSave()
```

### Sync Toggle (No App Restart)
Actually tears down and rebuilds the persistent store — not just a flag.

```swift
try await syncManager.setSyncEnabled(false)  // Stops CloudKit immediately
try await syncManager.setSyncEnabled(true)   // Starts CloudKit, checks account
```

### Force Sync with Completion
Monitors CloudKit events to know when sync actually finishes.

```swift
let result = try await syncManager.forceSync()
print("Success: \(result.success), took \(result.duration)s")
```

### Per-Entity Conflict Resolution
Different merge strategies for different entities via custom `NSMergePolicy` subclass.

Built-in strategies:
- `ServerWinsStrategy` — Remote values always win (default)
- `LocalWinsStrategy` — Local values always win
- `LatestTimestampStrategy` — Most recent edit wins
- `MaxValueStrategy` — Keep highest value for specified fields
- `SRSMergeStrategy` — Min for ease factor, max for streaks/reviews

Implement `ConflictResolutionStrategy` for custom logic.

### Duplicate Cleaning
Generic dedup that works with any Core Data entity.

```swift
let result = try await syncManager.duplicateCleaner.clean(
    entityType: KanaProgress.self,
    groupBy: \.character,
    keepStrategy: .keepHighestValue(forKey: "totalReviews"),
    in: syncManager.rawViewContext
)
```

### Status Monitoring
Real-time CloudKit status via `@Published` properties.

```swift
syncManager.syncStatus    // .available, .syncing(.importing), .error(.quotaExceeded), etc.
syncManager.lastSyncDate  // Optional<Date>
syncManager.recentEvents  // [SyncEvent] — last 50 events
```

## Requirements

- iOS 16+ / macOS 13+
- Swift 5.9+
- Core Data model with `usedWithCloudKit="YES"`

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/castlewong/CloudSyncKit.git", from: "0.1.0")
]
```

## Architecture

```
CloudSyncKit/
├── Core/
│   ├── CloudSyncManager        — Main @ObservableObject entry point
│   ├── CloudSyncConfiguration  — All config options
│   ├── SyncStatus              — Status enum, events, errors
│   └── StoreCoordinator        — Container lifecycle management
├── Context/
│   ├── SafeManagedObjectContext — Save-safe context wrapper
│   └── ContextProvider         — View/background context factory
├── Conflict/
│   ├── ConflictResolutionStrategy — Protocol for custom resolution
│   ├── MergeStrategyPresets       — Built-in strategies
│   └── EntityConflictRouter       — Per-entity NSMergePolicy subclass
├── Sync/
│   ├── SyncEventMonitor        — CloudKit event observer
│   ├── SyncToggleController    — Full enable/disable with store rebuild
│   └── ForceSyncOperation      — Async force sync with completion
├── Dedup/
│   └── DuplicateCleaner        — Generic duplicate detection & cleanup
├── Views/
│   ├── CloudSyncToggle         — Drop-in settings toggle
│   ├── SyncStatusIndicator     — Status badge/label
│   └── SyncDebugPanel          — Full debug view
└── Extensions/
    ├── NSManagedObjectContext+SafeSave
    └── NSPersistentStoreDescription+CloudKit
```

## License

MIT
