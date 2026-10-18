import SwiftUI

/// Opened from Profile, and from AuthWelcomeView during registration —
/// picks AppState.preferredLanguage, which CoreAppApp.swift's RootView
/// applies as `.environment(\.locale)` (so every `Text("...")`
/// string-literal lookup in Localizable.xcstrings resolves against it).
/// Takes effect immediately — no relaunch needed.
struct LanguagePickerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Settings", color: .appAccentPurple)
                        Text("Language")
                            .font(.brand(28))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, language in
                            if index > 0 { AppDivider() }
                            languageRow(language)
                        }
                    }
                    .glassCard(padding: 0)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .screenPadding()
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    private func languageRow(_ language: AppLanguage) -> some View {
        let isSelected = appState.preferredLanguage == language
        return Button {
            withAnimation(.easeInOut) { appState.preferredLanguage = language }
        } label: {
            HStack {
                Text(language.nativeName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.appAccentPurple)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LanguagePickerView()
        .environmentObject(AppState())
}
