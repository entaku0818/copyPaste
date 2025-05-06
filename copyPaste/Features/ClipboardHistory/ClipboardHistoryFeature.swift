import Foundation
import ComposableArchitecture

@Reducer
struct ClipboardHistoryFeature {
    @ObservableState
    struct State: Equatable {
        var items: [ClipboardItem] = []
        let maxItems: Int = 100
    }
    
    enum Action {
        case addItem(ClipboardItem)
        case removeItems(IndexSet)
        case clearAll
        case pasteItem(ClipboardItem)
    }
    
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
            }
        }
    }
} 