import SwiftUI
import ComposableArchitecture

struct MonitoringView: View {
    let store: StoreOf<ClipboardHistoryFeature>

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    // PiP ソースビュー（非表示アンカー）
                    PiPSourceView { sourceView in
                        PiPManager.shared.setup(sourceView: sourceView)
                        PiPManager.shared.onPiPStateChange = { isActive in
                            store.send(.pipStateChanged(isActive))
                        }
                        // 既存のアイテムを PiP に反映
                        PiPManager.shared.updateItems(store.items)
                    }
                    .frame(width: 1, height: 1)
                    .opacity(0)

                    HStack {
                        Circle()
                            .fill(store.isPiPActive ? Color.green : Color.blue)
                            .frame(width: 8, height: 8)
                        Text(store.isPiPActive ? String(localized: "monitoring.active") : String(localized: "monitoring.inactive"))
                            .font(.caption)
                            .foregroundColor(store.isPiPActive ? .green : .blue)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.vertical, 8)
            } header: {
                Text("monitoring.backgroundSection")
            } footer: {
                Text("monitoring.pipDescription")
                    .font(.caption2)
            }

            Section {
                HStack {
                    Circle()
                        .fill(store.isMonitoring ? Color.blue : Color.gray)
                        .frame(width: 10, height: 10)

                    Text(store.isMonitoring ? String(localized: "monitoring.statusActive") : String(localized: "monitoring.statusStopped"))
                        .font(.subheadline)
                        .foregroundColor(store.isMonitoring ? .blue : .secondary)

                    Spacer()

                    Button(store.isMonitoring ? "Stop" : "Start") {
                        store.send(store.isMonitoring ? .stopMonitoring : .startMonitoring)
                    }
                    .tint(store.isMonitoring ? .red : .blue)
                }
                .padding(.vertical, 4)

                if store.isMonitoring {
                    Button {
                        PiPManager.shared.startPiP()
                    } label: {
                        Label("monitoring.openPiP", systemImage: "pip.enter")
                    }
                    .tint(.blue)
                }
            } header: {
                Text("monitoring.controlSection")
            }
        }
        .navigationTitle("monitoring.title")
        .onAppear {
            store.send(.onAppear)
            store.send(.startMonitoring)
        }
        .alert(
            "permission.title",
            isPresented: Binding(
                get: { store.showPermissionAlert },
                set: { if !$0 { store.send(.dismissPermissionAlert) } }
            )
        ) {
            Button("permission.allow") {
                store.send(.requestClipboardPermission)
            }
            Button("permission.later", role: .cancel) {
                store.send(.dismissPermissionAlert)
            }
        } message: {
            Text("permission.message")
        }
    }
}
