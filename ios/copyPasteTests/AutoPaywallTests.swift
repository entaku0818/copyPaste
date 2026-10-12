import XCTest
import ComposableArchitecture
@testable import ClipKit

// MARK: - 自動の課金案内（issue #115: オンボーディング直後に1回＋非課金に30日に1回）

final class AutoPaywallPolicyTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func decide(
        isPro: Bool = false,
        isForeground: Bool = true,
        hasCompetingPrompt: Bool = false,
        didShowAppOpenAd: Bool = false,
        lastFullScreenAdAt: Date? = nil,
        record: AutoPaywallRecord
    ) -> AutoPaywallPolicy.Decision {
        AutoPaywallPolicy.decide(
            now: now,
            isPro: isPro,
            isForeground: isForeground,
            hasCompetingPrompt: hasCompetingPrompt,
            didShowAppOpenAd: didShowAppOpenAd,
            lastFullScreenAdAt: lastFullScreenAdAt,
            record: record
        )
    }

    /// 猶予期間を過ぎ、一度も案内していない非課金ユーザー
    private var dueRecord: AutoPaywallRecord {
        AutoPaywallRecord(firstSeenAt: now.addingTimeInterval(-4 * day), lastShownAt: nil)
    }

    // MARK: - オンボーディング直後

    func testOnboardingTrial_showsRightAfterOnboarding() {
        // 初回起動（起点を記録した直後）でも、猶予期間に関係なく1回だけ出す
        let record = AutoPaywallRecord(firstSeenAt: now, lastShownAt: nil, onboardingTrialPending: true)
        XCTAssertEqual(decide(record: record), .show(.onboardingTrial))
    }

    func testOnboardingTrial_notShownToPro() {
        let record = AutoPaywallRecord(firstSeenAt: now, onboardingTrialPending: true)
        XCTAssertEqual(decide(isPro: true, record: record), .skip(.pro))
    }

    func testOnboardingTrial_waitsForCompetingPrompt() {
        // クリップボード許可アラートと重ねない
        let record = AutoPaywallRecord(firstSeenAt: now, onboardingTrialPending: true)
        XCTAssertEqual(decide(hasCompetingPrompt: true, record: record), .skip(.competingPrompt))
    }

    // MARK: - 日数

    func testMonthly_notShownWithinGracePeriod() {
        let record = AutoPaywallRecord(firstSeenAt: now.addingTimeInterval(-3 * day + 60))
        XCTAssertEqual(decide(record: record), .skip(.gracePeriod))
    }

    func testMonthly_shownJustAfterGracePeriod() {
        let record = AutoPaywallRecord(firstSeenAt: now.addingTimeInterval(-3 * day))
        XCTAssertEqual(decide(record: record), .show(.monthlyPrompt))
    }

    func testMonthly_notShownWithoutFirstSeen() {
        XCTAssertEqual(decide(record: AutoPaywallRecord()), .skip(.gracePeriod))
    }

    func testMonthly_throttledWithin30Days() {
        var record = dueRecord
        record.lastShownAt = now.addingTimeInterval(-30 * day + 60)
        XCTAssertEqual(decide(record: record), .skip(.throttled))
    }

    func testMonthly_shownAfter30Days() {
        var record = dueRecord
        record.lastShownAt = now.addingTimeInterval(-30 * day)
        XCTAssertEqual(decide(record: record), .show(.monthlyPrompt))
    }

    func testMonthly_onboardingTrialCountsAsShown() {
        // オンボーディング直後のトライアル案内から30日は月1案内を重ねない
        let record = AutoPaywallRecord(
            firstSeenAt: now.addingTimeInterval(-10 * day),
            lastShownAt: now.addingTimeInterval(-10 * day)
        )
        XCTAssertEqual(decide(record: record), .skip(.throttled))
    }

    // MARK: - 課金状態

    func testMonthly_notShownToPro() {
        XCTAssertEqual(decide(isPro: true, record: dueRecord), .skip(.pro))
    }

    // MARK: - 除外条件

    func testNotShownInBackgroundOrPiP() {
        XCTAssertEqual(decide(isForeground: false, record: dueRecord), .skip(.notForeground))
    }

    func testNotShownWhenAppOpenAdShownThisLaunch() {
        XCTAssertEqual(decide(didShowAppOpenAd: true, record: dueRecord), .skip(.appOpenAdShown))
    }

    func testNotShownRightAfterFullScreenAd() {
        // インタースティシャル等を出してから10分以内
        let recent = now.addingTimeInterval(-9 * 60)
        XCTAssertEqual(decide(lastFullScreenAdAt: recent, record: dueRecord), .skip(.recentFullScreenAd))
    }

    func testShownWhenFullScreenAdIsOldEnough() {
        let old = now.addingTimeInterval(-10 * 60)
        XCTAssertEqual(decide(lastFullScreenAdAt: old, record: dueRecord), .show(.monthlyPrompt))
    }

    func testNotShownOverOtherModal() {
        XCTAssertEqual(decide(hasCompetingPrompt: true, record: dueRecord), .skip(.competingPrompt))
    }

    // MARK: - 保存

    func testStorage_roundTrip() {
        let defaults = UserDefaults(suiteName: "AutoPaywallPolicyTests-\(UUID().uuidString)")!
        XCTAssertEqual(AutoPaywallStorage.load(defaults), AutoPaywallRecord())

        AutoPaywallStorage.recordFirstSeenIfNeeded(defaults, now: now)
        AutoPaywallStorage.recordFirstSeenIfNeeded(defaults, now: now.addingTimeInterval(day))
        AutoPaywallStorage.markOnboardingCompleted(defaults)
        XCTAssertEqual(
            AutoPaywallStorage.load(defaults),
            AutoPaywallRecord(firstSeenAt: now, lastShownAt: nil, onboardingTrialPending: true),
            "起点は最初の1回だけ記録すること"
        )

        AutoPaywallStorage.markShown(now, defaults)
        AutoPaywallStorage.clearOnboardingTrial(defaults)
        XCTAssertEqual(
            AutoPaywallStorage.load(defaults),
            AutoPaywallRecord(firstSeenAt: now, lastShownAt: now, onboardingTrialPending: false)
        )
    }
}

// MARK: - reducer

@MainActor
final class AutoPaywallFeatureTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// 記録を LockIsolated に持つクライアント
    private func client(_ record: LockIsolated<AutoPaywallRecord>) -> AutoPaywallClient {
        AutoPaywallClient(
            load: { record.value },
            recordFirstSeenIfNeeded: {},
            markShown: { date in record.withValue { $0.lastShownAt = date } },
            clearOnboardingTrial: { record.withValue { $0.onboardingTrialPending = false } },
            lastFullScreenAdAt: { nil }
        )
    }

    private func makeStore(
        _ state: ClipboardHistoryFeature.State,
        record: LockIsolated<AutoPaywallRecord>,
        clock: TestClock<Duration> = TestClock()
    ) -> TestStoreOf<ClipboardHistoryFeature> {
        TestStore(initialState: state) {
            ClipboardHistoryFeature()
        } withDependencies: {
            $0.autoPaywall = client(record)
            $0.date.now = now
            $0.continuousClock = clock
        }
    }

    private var answeredPermissionState: ClipboardHistoryFeature.State {
        var state = ClipboardHistoryFeature.State(isProUser: false)
        state.hasRequestedPermission = true
        return state
    }

    func testMonthlyPrompt_showsPaywallAndSkipsReview() async {
        let record = LockIsolated(AutoPaywallRecord(firstSeenAt: now.addingTimeInterval(-5 * 86_400)))
        let store = makeStore(answeredPermissionState, record: record)

        await store.send(.checkAutoPaywall(didShowAppOpenAd: false, lastFullScreenAdAt: nil, thenCheckReview: true))
        // レビュー判定（checkReviewTrigger）へは進まない
        await store.receive(\.showPaywall) {
            $0.paywallSource = .monthlyPrompt
            $0.showPaywall = true
        }
        XCTAssertEqual(record.value.lastShownAt, now)
    }

    func testNotDue_fallsThroughToReviewCheck() async {
        let record = LockIsolated(AutoPaywallRecord(firstSeenAt: now))
        let store = makeStore(answeredPermissionState, record: record)

        await store.send(.checkAutoPaywall(didShowAppOpenAd: false, lastFullScreenAdAt: nil, thenCheckReview: true))
        await store.receive(\.checkReviewTrigger)
        XCTAssertNil(record.value.lastShownAt)
    }

    func testPro_neverShown() async {
        var state = answeredPermissionState
        state.isProUser = true
        let record = LockIsolated(AutoPaywallRecord(firstSeenAt: now.addingTimeInterval(-60 * 86_400)))
        let store = makeStore(state, record: record)

        await store.send(.checkAutoPaywall(didShowAppOpenAd: false, lastFullScreenAdAt: nil, thenCheckReview: true))
        await store.receive(\.checkReviewTrigger)
        XCTAssertNil(record.value.lastShownAt)
    }

    func testOnboardingTrial_deferredUntilPermissionAlertClosed() async {
        // 初回起動: クリップボード許可アラートが未回答なので見送り、閉じたら出す
        let record = LockIsolated(AutoPaywallRecord(firstSeenAt: now, onboardingTrialPending: true))
        let clock = TestClock()
        var state = ClipboardHistoryFeature.State(isProUser: false)
        state.hasRequestedPermission = false
        let store = makeStore(state, record: record, clock: clock)

        await store.send(.checkAutoPaywall(didShowAppOpenAd: false, lastFullScreenAdAt: nil, thenCheckReview: true)) {
            $0.isAutoPaywallDeferred = true
        }
        await store.receive(\.checkReviewTrigger)
        XCTAssertTrue(record.value.onboardingTrialPending, "見送った回はトライアル案内を消費しない")

        await store.send(.dismissPermissionAlert) {
            $0.isAutoPaywallDeferred = false
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.checkAutoPaywall)
        await store.receive(\.showPaywall) {
            $0.paywallSource = .onboardingTrial
            $0.showPaywall = true
        }
        XCTAssertFalse(record.value.onboardingTrialPending, "出したら二度と出さない")
        XCTAssertEqual(record.value.lastShownAt, now, "トライアル案内も30日の間隔に数える")
    }

    func testOnboardingTrial_consumedEvenWhenSkippedForAd() async {
        let record = LockIsolated(AutoPaywallRecord(firstSeenAt: now, onboardingTrialPending: true))
        let store = makeStore(answeredPermissionState, record: record)

        await store.send(.checkAutoPaywall(didShowAppOpenAd: true, lastFullScreenAdAt: nil, thenCheckReview: true))
        await store.receive(\.checkReviewTrigger)
        XCTAssertFalse(record.value.onboardingTrialPending, "「直後に1回だけ」なので次の起動に持ち越さない")
    }

    func testDismissPermissionAlert_withoutDeferral_doesNothing() async {
        let store = makeStore(answeredPermissionState, record: LockIsolated(AutoPaywallRecord()))
        await store.send(.dismissPermissionAlert)
    }
}
