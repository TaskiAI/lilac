import SwiftUI

/// A quiet, dismissible panel docked above the spacing slider that offers a few
/// directions to continue. Reading is the point — tapping a line just dismisses
/// it (nothing is inserted into the writer's page). Styled to the page theme.
struct WritingAssistPanel: View {
    let theme: JournalTheme
    let suggestions: [String]
    let onPick: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(theme.margin)
                Text("Feeling stuck? A few directions")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.ink.opacity(0.7))
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.ink.opacity(0.4))
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss suggestions")
            }

            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onPick(suggestion)
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption2)
                            .foregroundStyle(theme.margin)
                            .padding(.top, 3)
                        Text(suggestion)
                            .font(.system(.subheadline, design: .serif))
                            .foregroundStyle(theme.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.paper)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.rule).frame(height: 0.75)
        }
    }
}
