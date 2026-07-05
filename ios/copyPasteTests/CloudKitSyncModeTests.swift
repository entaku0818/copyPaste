import XCTest
import CoreData
@testable import ClipKit

final class CloudKitSyncModeTests: XCTestCase {
    private let key = "cloudKitSyncMode"
    private var originalValue: String?

    override func setUp() {
        super.setUp()
        originalValue = UserDefaults.standard.string(forKey: key)
    }

    override func tearDown() {
        if let originalValue {
            UserDefaults.standard.set(originalValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    // MARK: - CloudKitSyncMode

    func testDefaultIsAll() {
        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertEqual(CloudKitSyncMode.current, .all)
        XCTAssertTrue(CloudKitSyncMode.current.isEnabled)
    }

    func testAllIsEnabled() {
        UserDefaults.standard.set("all", forKey: key)
        XCTAssertEqual(CloudKitSyncMode.current, .all)
        XCTAssertTrue(CloudKitSyncMode.current.isEnabled)
    }

    func testLegacyTextAndURLMigratesToAll() {
        UserDefaults.standard.set("textAndURL", forKey: key)
        XCTAssertEqual(CloudKitSyncMode.current, .all)
        XCTAssertTrue(CloudKitSyncMode.current.isEnabled)
    }

    func testUnknownValueFallsBackToDisabled() {
        UserDefaults.standard.set("unknown", forKey: key)
        XCTAssertEqual(CloudKitSyncMode.current, .disabled)
    }

    func testSetterPersists() {
        CloudKitSyncMode.current = .all
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "all")
        CloudKitSyncMode.current = .disabled
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "disabled")
    }

    // MARK: - PersistenceController

    func testPersistenceControllerWithoutCloudKitUsesPlainContainer() {
        let controller = PersistenceController(useCloudKit: false, inMemory: true)
        XCTAssertFalse(controller.isUsingCloudKit)
    }

    func testPersistenceControllerWithCloudKitUsesCloudKitContainer() {
        let controller = PersistenceController(useCloudKit: true, inMemory: true)
        XCTAssertTrue(controller.isUsingCloudKit)
    }
}
