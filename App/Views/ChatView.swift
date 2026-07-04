import SwiftUI
import AroundCore

struct ChatView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var viewModel: ChatViewModel
    @State private var draft = ""
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            Text("Around").font(.headline)
                            if let zone = viewModel.zone {
                                Text("zone \(zone)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("zoneChip")
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityIdentifier("settingsButton")
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView(viewModel: viewModel)
                }
                .alert("Couldn't send", isPresented: sendErrorBinding) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(viewModel.sendError ?? "")
                }
        }
        .onAppear { viewModel.start(senderID: model.senderID) }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.locationService.status {
        case .denied:
            ContentUnavailableView {
                Label("Location needed", systemImage: "location.slash")
            } description: {
                Text("Around finds your chat zone from your location. Enable it in Settings to join the conversation nearby.")
            } actions: {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        case .starting, .waitingForPermission, .locating:
            ProgressView("Finding your zone…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready, .pinned:
            messageArea
        }
    }

    private var messageArea: some View {
        Group {
            if viewModel.messages.isEmpty {
                ContentUnavailableView {
                    Label("It's quiet around here", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text(
                        viewModel.hasLoaded
                            ? "No one has said anything in the last 24 hours. Break the ice!"
                            : "Checking for messages nearby…"
                    )
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(
                                    message: message,
                                    isOwn: message.senderID == model.senderID
                                )
                                .id(message.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .accessibilityIdentifier("messageList")
                    .onChange(of: viewModel.messages.last?.id) { _, lastID in
                        if let lastID {
                            withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                        }
                    }
                    .onAppear {
                        if let lastID = viewModel.messages.last?.id {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { composeBar }
    }

    private var composeBar: some View {
        HStack(spacing: 10) {
            TextField("Say something nearby…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
                .accessibilityIdentifier("composeField")

            Button {
                let text = draft
                draft = ""
                Task {
                    await viewModel.send(
                        text: text,
                        senderID: model.senderID,
                        senderName: model.handle
                    )
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("sendButton")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var sendErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.sendError != nil },
            set: { if !$0 { viewModel.sendError = nil } }
        )
    }
}

struct MessageBubble: View {
    let message: Message
    let isOwn: Bool

    var body: some View {
        VStack(alignment: isOwn ? .trailing : .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(isOwn ? "you" : message.senderName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isOwn ? .teal : .secondary)
                Text(relativeTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(message.text)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    isOwn ? AnyShapeStyle(.teal.opacity(0.22)) : AnyShapeStyle(.quaternary.opacity(0.6)),
                    in: RoundedRectangle(cornerRadius: 16)
                )
            Text("fades \(fadesIn)")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
        .accessibilityElement(children: .combine)
    }

    private var relativeTime: String {
        if abs(message.sentAt.timeIntervalSinceNow) < 60 { return "now" }
        return Self.relativeFormatter.localizedString(for: message.sentAt, relativeTo: .now)
    }

    private var fadesIn: String {
        let remaining = MessageRules.expiryDate(of: message).timeIntervalSinceNow
        if remaining <= 0 { return "any moment" }
        let hours = Int((remaining / 3600).rounded(.up))
        return hours > 1 ? "in \(hours) h" : "within the hour"
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}
