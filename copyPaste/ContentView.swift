import SwiftUI
import ComposableArchitecture

public struct ContentView: View {
    let store: StoreOf<ClipboardHistoryFeature>
    
    public init(store: StoreOf<ClipboardHistoryFeature>) {
        self.store = store
    }
    
    public var body: some View {
        NavigationStack {
            ClipboardHistoryView(store: store)
        }
    }
}

#Preview {
    ContentView(
        store: Store(
            initialState: ClipboardHistoryFeature.State()
        ) {
            ClipboardHistoryFeature()
        }
    )
} 