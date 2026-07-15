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

    // MARK: - performBackgroundTask async timing

    /// waitUntilLoaded()がloadPersistentStoresの非同期完了を正しく待つことを確認する。
    /// 手動のディレイなしですぐperformBackgroundTaskを呼んでもレースせず、
    /// ストア読み込み完了後に安全に実行されることを検証する（issue #98）。
    func testPerformBackgroundTask_happyPath_waitsForStoreLoadAndSucceeds() async throws {
        let controller = PersistenceController(useCloudKit: false, inMemory: true)

        let result = try await controller.performBackgroundTask { _ in 1 }

        XCTAssertEqual(result, 1)
    }

    /// ストアの読み込みが実際に失敗した場合、performBackgroundTaskが
    /// PersistenceError.storeNotAvailableを投げることを確認する（issue #98）。
    ///
    /// 当初は「存在しないディレクトリ配下のURL」で失敗注入を試みたが、
    /// NSPersistentContainerが中間ディレクトリを自動作成してロードに成功してしまうことが
    /// 実測で判明した。そこで、既存のディレクトリそのものをストアURLとして渡すことで、
    /// SQLiteが「ファイルとして開けない（ディレクトリである）」という実際のCoreData読み込み
    /// 失敗を注入する。
    func testPerformBackgroundTask_storeLoadFailure_throwsStoreNotAvailable() async {
        // 既存のディレクトリをそのままストアURLとして渡す。
        // ディレクトリはSQLiteファイルとして開けないため、実際のロード失敗が発生する。
        let storeURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let controller = PersistenceController(useCloudKit: false, inMemory: false, storeURL: storeURL)

        do {
            _ = try await controller.performBackgroundTask { _ in 1 }
            XCTFail("ストア読み込み失敗時はエラーが投げられるべき")
        } catch let error as PersistenceError {
            switch error {
            case .storeNotAvailable:
                break
            }
        } catch {
            XCTFail("PersistenceError.storeNotAvailableが投げられるべきだが\(error)が投げられた")
        }
    }
}
