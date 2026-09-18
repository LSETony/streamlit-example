import SwiftUI

/// Opened from Home's "Core AI" tile — a real chat backed by a free, open
/// model through Pollinations' OpenAI-compatible endpoint (no API key,
/// same request/response shape as OpenAI's Chat Completions API, so any
/// OpenAI-compatible open-source backend can be swapped in by changing
/// `endpoint`/`model` below).
struct CoreAIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: .assistant, content: "Hey, I'm Core AI. Ask me about workouts, recovery, or anything else in the app.")
    ]
    @State private var draft = ""
    @State private var isSending = false
    @State private var errorText: String?
    @FocusState private var inputFocused: Bool

    private let endpoint = URL(string: "https://text.pollinations.ai/openai")!
    private let model = "openai"
    private let systemPrompt = "You are Core AI, the assistant inside the core. fitness club app. Answer briefly and helpfully about training, recovery, nutrition and using the app."

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                let reply = try await requestReply()
                await MainActor.run {
                    messages.append(ChatMessage(role: .assistant, content: reply))
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    errorText = "Couldn't reach Core AI — check your connection and try again."
                    isSending = false
                }
            }
        }
    }

    private func requestReply() async throws -> String {
        var apiMessages = [APIMessage(role: "system", content: systemPrompt)]
        apiMessages += messages.map { APIMessage(role: $0.role == .user ? "user" : "assistant", content: $0.content) }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(ChatCompletionRequest(model: model, messages: apiMessages))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
            throw URLError(.cannotParseResponse)
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    enum Role { case user, assistant }
}

private struct APIMessage: Codable {
    let role: String
    let content: String
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [APIMessage]
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Msg: Decodable { let content: String }
        let message: Msg
    }
    let choices: [Choice]
}

#Preview {
    CoreAIChatView()
}
