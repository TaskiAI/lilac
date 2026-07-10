import SwiftUI

/// A gentle, optional menu of prompts to help the writer begin — surfaced from
/// "Need a nudge?". Blends their own reflected-back prompt, focus-aligned
/// prompts, and the curated bank. Choosing one starts an entry from that exact
/// prompt (no AI rewrite); the writing is theirs.
struct PromptChooserView: View {
    let suggestions: [RecommendedPrompt]
    let onPick: (RecommendedPrompt) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Somewhere to start — only if it helps. Skip any that don't fit.")
                        .font(.footnote)
                        .foregroundStyle(Color.homeSecondary)
                        .padding(.bottom, 4)

                    ForEach(suggestions) { suggestion in
                        Button {
                            dismiss()
                            onPick(suggestion)
                        } label: {
                            PromptRow(suggestion: suggestion)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(
                LinearGradient(colors: [.homeBackgroundTop, .homeBackgroundBottom],
                               startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            )
            .navigationTitle("A nudge to begin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
            }
        }
        .tint(.homeAccent)
        .presentationDetents([.medium, .large])
    }
}

private struct PromptRow: View {
    let suggestion: RecommendedPrompt

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: suggestion.source.icon)
                .font(.subheadline)
                .foregroundStyle(Color.homeAccent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 5) {
                if let label = suggestion.source.label {
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.homeAccent)
                }
                Text(suggestion.text)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color.homeAccentDeep)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .homeCardBackground()
    }
}
