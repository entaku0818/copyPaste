import SwiftUI

/// キーボード拡張からのデバッグログを表示するビュー（DEBUGビルド専用）
struct KeyboardLogView: View {
    @State private var entries: [String] = []
    @State private var showCopied = false

    private let logKey = "keyboard_debug_logs"

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "ログなし",
                    systemImage: "keyboard",
                    description: Text("キーボード拡張を起動すると\nここにログが表示されます")
                )
            } else {
                List {
                    ForEach(entries.reversed(), id: \.self) { entry in
                        Text(entry)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(foregroundColor(for: entry))
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("キーボードログ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    copyLogs()
                } label: {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                }

                Button(role: .destructive) {
                    clearLogs()
                } label: {
                    Image(systemName: "trash")
                }
                .foregroundColor(.red)
            }
        }
        .onAppear {
            loadLogs()
        }
        .onReceive(
            Timer.publish(every: 3, on: .main, in: .common).autoconnect()
        ) { _ in
            loadLogs()
        }
    }

    private func loadLogs() {
        entries = UserDefaults(suiteName: "group.com.entaku.clipkit")?
            .stringArray(forKey: logKey) ?? []
    }

    private func clearLogs() {
        UserDefaults(suiteName: "group.com.entaku.clipkit")?.removeObject(forKey: logKey)
        entries = []
    }

    private func copyLogs() {
        let text = entries.joined(separator: "\n")
        UIPasteboard.general.string = text
        withAnimation {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
    }

    private func foregroundColor(for entry: String) -> Color {
        if entry.contains("❌") { return .red }
        if entry.contains("✅") { return .green }
        if entry.contains("🚀") { return .blue }
        if entry.contains("✏️") { return .orange }
        return .primary
    }
}

#Preview {
    NavigationStack {
        KeyboardLogView()
    }
}
