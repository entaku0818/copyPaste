import SwiftUI
import ComposableArchitecture

struct ClipboardHistoryView: View {
    let store: StoreOf<ClipboardHistoryFeature>
    
    var body: some View {
        List {
            ForEach(store.items) { item in
                VStack(alignment: .leading) {
                    Text(item.content)
                        .lineLimit(2)
                    Text(item.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    store.send(.pasteItem(item))
                }
            }
            .onDelete { indexSet in
                store.send(.removeItems(indexSet))
            }
        }
        .navigationTitle("Clipboard History")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(store.isMonitoring ? "Stop Monitoring" : "Start Monitoring") {
                    store.send(store.isMonitoring ? .stopMonitoring : .startMonitoring)
                }
                .tint(store.isMonitoring ? .red : .blue)
                
                Button("Clear All") {
                    store.send(.clearAll)
                }
            }
        }
        .task {
            store.send(.startMonitoring)
        }
    }
} 