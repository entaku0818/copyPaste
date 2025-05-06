import Foundation
import ComposableArchitecture
import UIKit

@Reducer
struct ClipboardHistoryFeature {
    @ObservableState
    struct State: Equatable {
        var items: [ClipboardItem] = []
        let maxItems: Int = 100
        var isMonitoring: Bool = false
        var lastChangeCount: Int = UIPasteboard.general.changeCount
        var isAppActive: Bool = true
    }
    
    enum Action {
        case addItem(ClipboardItem)
        case removeItems(IndexSet)
        case clearAll
        case pasteItem(ClipboardItem)
        case startMonitoring
        case stopMonitoring
        case checkClipboard
        case onAppear
        case appDidBecomeActive
        case appDidEnterBackground
    }
    
    @Dependency(\.continuousClock) var clock
    private enum CancelID { case monitoring }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .addItem(item):
                state.items.insert(item, at: 0)
                if state.items.count > state.maxItems {
                    state.items.removeLast()
                }
                return .none
                
            case let .removeItems(indexSet):
                state.items.remove(atOffsets: indexSet)
                return .none
                
            case .clearAll:
                state.items.removeAll()
                return .none
                
            case .pasteItem:
                // Paste functionality will be implemented later
                return .none
                
            case .startMonitoring:
                guard !state.isMonitoring else { return .none }
                state.isMonitoring = true
                PiPManager.shared.startPiP()
                
                return .run { send in
                    // アプリの状態変化を監視
                    NotificationCenter.default.addObserver(
                        forName: UIApplication.didBecomeActiveNotification,
                        object: nil,
                        queue: .main
                    ) { _ in
                        Task {
                            await send(.appDidBecomeActive)
                        }
                    }
                    
                    NotificationCenter.default.addObserver(
                        forName: UIApplication.didEnterBackgroundNotification,
                        object: nil,
                        queue: .main
                    ) { _ in
                        Task {
                            await send(.appDidEnterBackground)
                        }
                    }
                    
                    // 1秒ごとにクリップボードをチェック
                    for await _ in clock.timer(interval: .seconds(1)) {
                        await send(.checkClipboard)
                    }
                }
                .cancellable(id: CancelID.monitoring)
                
            case .stopMonitoring:
                guard state.isMonitoring else { return .none }
                state.isMonitoring = false
                PiPManager.shared.stopPiP()
                return .cancel(id: CancelID.monitoring)
                
            case .checkClipboard:
                // アプリがアクティブでない場合はスキップ
                guard state.isAppActive else { return .none }
                
                do {
                    let currentChangeCount = UIPasteboard.general.changeCount
                    guard currentChangeCount != state.lastChangeCount else {
                        return .none
                    }
                    
                    state.lastChangeCount = currentChangeCount
                    if let content = UIPasteboard.general.string {
                        let item = ClipboardItem(content: content)
                        return .send(.addItem(item))
                    }
                } catch {
                    print("Clipboard access error: \(error.localizedDescription)")
                }
                return .none
                
            case .appDidBecomeActive:
                state.isAppActive = true
                return .none
                
            case .appDidEnterBackground:
                state.isAppActive = false
                return .none
                
            case .onAppear:
                // 画面表示時に現在のクリップボードの内容を取得
                guard let content = UIPasteboard.general.string else { return .none }
                let item = ClipboardItem(content: content)
                return .send(.addItem(item))
            }
        }
    }
} 