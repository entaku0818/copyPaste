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
    }
    
    enum Action {
        case addItem(ClipboardItem)
        case removeItems(IndexSet)
        case clearAll
        case pasteItem(ClipboardItem)
        case startMonitoring
        case stopMonitoring
        case clipboardChanged
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
                
                return .run { send in
                    let notificationCenter = NotificationCenter.default
                    let pasteboardChangedNotification = UIPasteboard.changedNotification
                    
                    for await _ in notificationCenter.notifications(named: pasteboardChangedNotification) {
                        await send(.clipboardChanged)
                    }
                }
                .cancellable(id: CancelID.monitoring)
                
            case .stopMonitoring:
                guard state.isMonitoring else { return .none }
                state.isMonitoring = false
                return .cancel(id: CancelID.monitoring)
                
            case .clipboardChanged:
                guard let content = UIPasteboard.general.string else { return .none }
                let item = ClipboardItem(content: content)
                return .send(.addItem(item))
            }
        }
    }
} 