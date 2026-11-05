import AppIntents
import Combine

/// Retains a cold-launch request until the main screen is ready (including onboarding).
@MainActor
final class PiPLaunchRequest: ObservableObject {
    static let shared = PiPLaunchRequest()
    @Published private(set) var isPending = false

    func request() { isPending = true }
    func consume() { isPending = false }
}

struct OpenPiPIntent: AppIntent {
    static var title: LocalizedStringResource = "shortcut.openPiP"
    static var description = IntentDescription("shortcut.openPiPDescription")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        PiPLaunchRequest.shared.request()
        return .result()
    }
}

struct ClipKitShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenPiPIntent(),
            phrases: ["Open PiP in \(.applicationName)"],
            shortTitle: "shortcut.openPiP",
            systemImageName: "pip.enter"
        )
    }
}
