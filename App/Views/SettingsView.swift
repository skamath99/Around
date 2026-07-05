import SwiftUI
import AroundCore

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var zoneCopied = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                            .foregroundStyle(.teal)
                            .accessibilityHidden(true)
                        TextField("Handle", text: $model.handle)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .accessibilityIdentifier("settingsHandleField")
                    }
                } header: {
                    Text("Your handle")
                } footer: {
                    Text("The only setting you can change — how your name appears to people nearby.")
                }

                Section {
                    LabeledContent("Zone code") {
                        if let zone = viewModel.zone {
                            HStack(spacing: 8) {
                                Text(zone)
                                    .monospaced()
                                Button {
                                    UIPasteboard.general.string = zone
                                    zoneCopied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        zoneCopied = false
                                    }
                                } label: {
                                    Image(systemName: zoneCopied ? "checkmark" : "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Copy zone code")
                                .accessibilityIdentifier("copyZoneButton")
                            }
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = zone
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                        } else {
                            Text("locating…")
                                .monospaced()
                        }
                    }
                } header: {
                    Text("Your zone")
                } footer: {
                    Text("A zone is about 150 m across. You also see the 8 zones touching yours, so conversations don't cut off at a border.")
                }

                Section {
                    LabeledContent("Messages fade after", value: "24 hours")
                    LabeledContent("Backend", value: viewModel.transportDescription)
                } header: {
                    Text("About Around")
                } footer: {
                    Text("Messages are visible to anyone in your zone and pass through Apple's iCloud servers. Around attaches only your zone code — never your exact coordinates — but it is not anonymous to Apple. Don't share anything sensitive.")
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
