import SwiftUI
import FirebaseFunctions

enum FeedbackCategory: String, CaseIterable {
    case bug = "bug"
    case feature = "feature"
    case other = "other"

    var displayName: String {
        switch self {
        case .bug: return String(localized: "feedbackCategory.bug")
        case .feature: return String(localized: "feedbackCategory.feature")
        case .other: return String(localized: "feedbackCategory.other")
        }
    }
}

struct FeedbackFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var category: FeedbackCategory = .feature
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var isSending = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String = ""

    private var canSubmit: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("feedback.category") {
                    Picker("feedback.category", selection: $category) {
                        ForEach(FeedbackCategory.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("feedback.content") {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                }
                Section("feedback.email") {
                    TextField("feedback.emailPlaceholder", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("feedback.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSending {
                        ProgressView()
                    } else {
                        Button("feedback.send") { submit() }
                            .disabled(!canSubmit)
                    }
                }
            }
            .alert("feedback.success", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("feedback.successMessage")
            }
            .alert("feedback.failure", isPresented: $showErrorAlert) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func submit() {
        isSending = true
        Task {
            do {
                try await sendFeedback(category: category.rawValue, message: message, email: email)
                isSending = false
                showSuccessAlert = true
            } catch {
                isSending = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}

private func sendFeedback(category: String, message: String, email: String) async throws {
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    let osVersion = UIDevice.current.systemVersion
    let deviceModel = UIDevice.current.model

    let functions = Functions.functions(region: "asia-northeast1")
    var data: [String: Any] = [
        "category": category,
        "message": message,
        "appVersion": appVersion,
        "buildNumber": buildNumber,
        "osVersion": osVersion,
        "deviceModel": deviceModel,
    ]
    if !email.isEmpty { data["email"] = email }
    _ = try await functions.httpsCallable("submitFeedback").call(data)
}

#Preview {
    FeedbackFormView()
}
