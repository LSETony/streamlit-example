import SwiftUI
import FoundationModels

/// Opened from Home's "Core AI" tile — a real chat powered by Apple's
/// Foundation Models framework, running fully on-device (iOS 26). No
/// network call and no API key: the earlier version called a free
/// third-party HTTP endpoint and that kept failing to connect, so this
/// switches to the on-device model instead, which has nothing to be
/// unreachable from.
struct CoreAIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, content: "Hey, I'm Core AI. Ask me about workouts, recovery, or anything else in the app.")
    ]
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorText: String?
    @State private var session = LanguageModelSession(
        instructions: "You are Core AI, the assistant inside the core. fitness club app. Answer briefly and helpfully about training, recovery, nutrition and using the app."
    )
    @FocusState private var inputFocused: Bool

    private var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if case .unavailable(let reason) = availability {
                    Text(unavailableMessage(reason))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.appWarning)
                        .padding(.horizontal, AppMetrics.screenPadding)
                        .padding(.top, 10)
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(messages) { message in
                                bubble(message)
                            }
                            if isSending {
                                typingBubble
                            }
                            if let errorText {
                                Text(errorText)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.appWarning)
                            }
                        }
                        .padding(.horizontal, AppMetrics.screenPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 12)
                        .id("bottom")
                    }
                    .onChange(of: messages.count) {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                    .onChange(of: isSending) {
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }

                inputBar
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Core AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    private func unavailableMessage(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence, so Core AI can't run here."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to use Core AI."
        case .modelNotReady:
            return "Core AI's on-device model is still downloading — try again shortly."
        @unknown default:
            return "Core AI isn't available right now."
        }
    }

    private func bubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.content)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.role == .user ? Color.appAccent : Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var typingBubble: some View {
        HStack {
            ProgressView()
                .tint(Color.appTextSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
            Spacer(minLength: 40)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("", text: $draft, prompt: Text("Ask Core AI…").foregroundStyle(Color.appTextSecondary), axis: .vertical)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: Capsule())

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.tint(.appAccent).interactive(), in: Circle())
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending ? 0.4 : 1)
        }
        .padding(.horizontal, AppMetrics.screenPadding)
        .padding(.vertical, 10)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        messages.append(ChatMessage(role: .user, content: text))
        draft = ""
        errorText = nil
        isSending = true

        Task {
            do {
                let response = try await session.respond(to: text)
                await MainActor.run {
                    messages.append(ChatMessage(role: .assistant, content: response.content))
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    errorText = "Core AI couldn't answer that — try rephrasing or ask again."
                    isSending = false
                }
            }
        }
    }
}

private struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    enum Role { case user, assistant }
}

#Preview {
    CoreAIChatView()
}
