import SwiftUI

struct AIAssistantView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(appState.chatMessages) { message in
                            ChatBubble(message: message)
                        }
                    }
                    .screenPadding()
                    .padding(.vertical, 16)
                    .id("bottom")
                }
                .onChange(of: appState.chatMessages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            if appState.chatMessages.count <= 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AppState.suggestedQuestions, id: \.self) { question in
                            Button {
                                appState.sendChatMessage(question)
                            } label: {
                                Text(question)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.appSurface)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .screenPadding()
                }
                .padding(.bottom, 10)
            }

            HStack(spacing: 10) {
                TextField("Ask about training, food or a supplement", text: $draft)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.appSurface)
                    .clipShape(Capsule())
                Button {
                    appState.sendChatMessage(draft)
                    draft = ""
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.appAccent).interactive(), in: Circle())
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .screenPadding()
            .padding(.bottom, 16)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("core AI")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
            }
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }
            Text(message.text)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.isUser ? Color.appAccent : Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            if !message.isUser { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    NavigationStack { AIAssistantView() }
        .environmentObject(AppState())
}
