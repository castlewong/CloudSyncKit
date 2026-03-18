import XCTest
@testable import CloudSyncKit
import CoreData

final class CloudSyncConfigurationTests: XCTestCase {

    func testDefaultConfiguration() {
        let config = CloudSyncConfiguration(containerName: "TestApp")

        XCTAssertEqual(config.containerName, "TestApp")
        XCTAssertNil(config.cloudKitContainerIdentifier)
        XCTAssertTrue(config.enableSyncByDefault)
        XCTAssertTrue(config.automaticallyMergesChangesFromParent)
        XCTAssertEqual(config.maxEventLogSize, 50)
        XCTAssertEqual(config.forceSyncTimeout, 30)
        XCTAssertEqual(config.syncEnabledKey, "CloudSyncKit_iCloudSyncEnabled")
        XCTAssertTrue(config.entityConflictStrategies.isEmpty)
    }

    func testCustomConfiguration() {
        let config = CloudSyncConfiguration(
            containerName: "MyApp",
            cloudKitContainerIdentifier: "iCloud.com.test.myapp",
            enableSyncByDefault: false,
            maxEventLogSize: 100,
            forceSyncTimeout: 60
        )

        XCTAssertEqual(config.containerName, "MyApp")
        XCTAssertEqual(config.cloudKitContainerIdentifier, "iCloud.com.test.myapp")
        XCTAssertFalse(config.enableSyncByDefault)
        XCTAssertEqual(config.maxEventLogSize, 100)
        XCTAssertEqual(config.forceSyncTimeout, 60)
    }
}

final class SyncStatusTests: XCTestCase {

    func testIsOperational() {
        XCTAssertTrue(SyncStatus.available.isOperational)
        XCTAssertTrue(SyncStatus.syncing(.exporting).isOperational)
        XCTAssertFalse(SyncStatus.unknown.isOperational)
        XCTAssertFalse(SyncStatus.notSignedIn.isOperational)
        XCTAssertFalse(SyncStatus.disabled.isOperational)
        XCTAssertFalse(SyncStatus.error(.networkUnavailable).isOperational)
    }

    func testLocalizedDescriptions() {
        XCTAssertEqual(SyncStatus.available.localizedDescription, "Available")
        XCTAssertEqual(SyncStatus.disabled.localizedDescription, "Disabled")
        XCTAssertEqual(SyncStatus.notSignedIn.localizedDescription, "Not signed in to iCloud")
        XCTAssertEqual(SyncStatus.syncing(.importing).localizedDescription, "Importing")
    }
}

final class SyncErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertNotNil(SyncError.notAuthenticated.errorDescription)
        XCTAssertNotNil(SyncError.networkUnavailable.errorDescription)
        XCTAssertNotNil(SyncError.quotaExceeded.errorDescription)
        XCTAssertNotNil(SyncError.rateLimited.errorDescription)
        XCTAssertNotNil(SyncError.storeNotReady.errorDescription)
    }

    func testEquality() {
        XCTAssertEqual(SyncError.notAuthenticated, SyncError.notAuthenticated)
        XCTAssertNotEqual(SyncError.notAuthenticated, SyncError.networkUnavailable)
        XCTAssertEqual(SyncError.underlying("test"), SyncError.underlying("test"))
        XCTAssertNotEqual(SyncError.underlying("a"), SyncError.underlying("b"))
    }
}

final class SyncEventTests: XCTestCase {

    func testEventCreation() {
        let event = SyncEvent(type: .exporting, succeeded: true)

        XCTAssertTrue(event.succeeded)
        XCTAssertEqual(event.type, .exporting)
        XCTAssertNil(event.errorMessage)
    }

    func testEventWithError() {
        let event = SyncEvent(type: .importing, succeeded: false, errorMessage: "Network timeout")

        XCTAssertFalse(event.succeeded)
        XCTAssertEqual(event.errorMessage, "Network timeout")
    }
}

final class MergeStrategyTests: XCTestCase {

    // Note: Full conflict resolution tests require a Core Data stack.
    // These tests verify the strategy API compiles and the types are correct.

    func testServerWinsStrategyExists() {
        let strategy = ServerWinsStrategy()
        XCTAssertNotNil(strategy)
    }

    func testLocalWinsStrategyExists() {
        let strategy = LocalWinsStrategy()
        XCTAssertNotNil(strategy)
    }

    func testLatestTimestampStrategyDefaults() {
        let strategy = LatestTimestampStrategy()
        XCTAssertEqual(strategy.timestampKey, "updatedAt")
    }

    func testMaxValueStrategyCreation() {
        let strategy = MaxValueStrategy(
            maxFields: ["score", "level"],
            fallback: ServerWinsStrategy()
        )
        XCTAssertEqual(strategy.maxFields, ["score", "level"])
    }

    func testSRSMergeStrategyDefaults() {
        let strategy = SRSMergeStrategy()
        XCTAssertEqual(strategy.minFields, ["easeFactor"])
        XCTAssertEqual(strategy.maxFields, ["correctStreak", "totalReviews"])
    }
}

final class DuplicateCleanResultTests: XCTestCase {

    func testResultCreation() {
        let result = DuplicateCleanResult(
            groupsProcessed: 5,
            duplicatesFound: 12,
            duplicatesRemoved: 12
        )
        XCTAssertEqual(result.groupsProcessed, 5)
        XCTAssertEqual(result.duplicatesFound, 12)
        XCTAssertEqual(result.duplicatesRemoved, 12)
    }
}
