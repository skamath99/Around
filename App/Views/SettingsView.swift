import SwiftUI
import AroundCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Your handle") {
                    TextField("Handle", text: $model.handle)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("settingsHandleField")
                }

                Section("Your zone") {
                    LabeledContent("Zone code") {
                        Text(viewModel.zone ?? "locating…")
                            .monospaced()
                    }
                    Text("A zone is about 150 m across. You also see the 8 zones touching yours, so conversations don't cut off at a border.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("How Around works") {
                    LabeledContent("Messages fade after", value: "24 hours")
                    LabeledContent("Backend", value: viewModel.transportDescription)
                    Text("Messages are visible to anyone in your zone and pass through Apple's iCloud servers. Around attaches only your zone code — never your exact coordinates — but it is not anonymous to Apple. Don't share anything sensitive.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.shortVersion)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settingsDoneButton")
                }
            }
        }
    }
}

private extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }
}
