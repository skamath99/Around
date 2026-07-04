import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if model.onboarded {
            ChatView(viewModel: model.chat)
        } else {
            OnboardingView()
        }
    }
}
