import SwiftUI
import AroundCore

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var handle = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(.teal)
                .padding(24)
                .background(.teal.opacity(0.12), in: Circle())

            Text("Around")
                .font(.largeTitle.bold())
                .padding(.top, 16)
            Text("Ephemeral chat with whoever's nearby.")
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 18) {
                featureRow(
                    icon: "location.circle",
                    title: "One room per block",
                    detail: "Everyone within your ~150 m zone shares the conversation."
                )
                featureRow(
                    icon: "clock.arrow.circlepath",
                    title: "Messages fade in 24 hours",
                    detail: "Nothing sticks around. Come back tomorrow to a clean slate."
                )
                featureRow(
                    icon: "eye",
                    title: "Public to your zone",
                    detail: "Anyone nearby can read what you post — keep secrets off it."
                )
            }
            .padding(.horizontal, 32)
            .padding(.top, 36)

            Spacer()

            VStack(spacing: 12) {
                HStack {
                    TextField("Your handle", text: $handle)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityIdentifier("handleField")
                    Button {
                        handle = HandleGenerator.random()
                    } label: {
                        Image(systemName: "shuffle")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("shuffleButton")
                }

                Button {
                    model.completeOnboarding(handle: handle)
                } label: {
                    Text("Start chatting")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("continueButton")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear { handle = model.handle }
    }

    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.teal)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
