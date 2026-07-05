import SwiftUI
import ComposableArchitecture

struct MonitoringView: View {
    let store: StoreOf<ClipboardHistoryFeature>

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClipKitSpacing.sectionGap) {
                // ヒーローカード（ダークサーフェス）
                DarkHeroCard {
                    VStack(spacing: 16) {
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

                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [ClipKitColor.indigoLight, ClipKitColor.indigo],
                                        center: .center, startRadius: 2, endRadius: 40
                                    )
                                )
                                .frame(width: 76, height: 76)
                                .shadow(color: ClipKitColor.indigoLight.opacity(0.6), radius: 20)
                            Image(systemName: store.isPiPActive ? "play.circle.fill" : "pause.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 6) {
                            Text(store.isPiPActive ? String(localized: "monitoring.active") : String(localized: "monitoring.inactive"))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(ClipKitColor.textOnDark)
                            Text("monitoring.pipDescription")
                                .font(.system(size: 12.5))
                                .foregroundColor(ClipKitColor.textOnDarkSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, ClipKitSpacing.screenPadding)

                SectionCaptionLabel(title: String(localized: "monitoring.controlSection"))
                    .padding(.horizontal, ClipKitSpacing.screenPadding + ClipKitSpacing.cardPadding)

                CardGroup {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(store.isMonitoring ? ClipKitColor.indigo : Color.gray)
                            .frame(width: 10, height: 10)

                        Text(store.isMonitoring ? String(localized: "monitoring.statusActive") : String(localized: "monitoring.statusStopped"))
                            .font(ClipKitFont.rowTitle)
                            .foregroundColor(ClipKitColor.textPrimary)

                        Spacer()

                        Button(store.isMonitoring ? "Stop" : "Start") {
                            store.send(store.isMonitoring ? .stopMonitoring : .startMonitoring)
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .tint(store.isMonitoring ? ClipKitColor.destructive : ClipKitColor.indigo)
                    }
                    .padding(.horizontal, ClipKitSpacing.cardPadding)
                    .padding(.vertical, ClipKitSpacing.rowVerticalPadding + 3)

                    if store.isMonitoring {
                        CardDivider()
                        Button {
                            PiPManager.shared.startPiP()
                        } label: {
                            HStack {
                                Image(systemName: "pip.enter")
                                Text("monitoring.openPiP")
                                Spacer()
                            }
                        }
                        .font(ClipKitFont.rowTitle)
                        .tint(ClipKitColor.indigo)
                        .padding(.horizontal, ClipKitSpacing.cardPadding)
                        .padding(.vertical, ClipKitSpacing.rowVerticalPadding + 3)
                    }
                }
                .padding(.horizontal, ClipKitSpacing.screenPadding)
            }
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(ClipKitColor.canvas)
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
