import SwiftUI

/// A prompted screen: the reusable journal page with a style + prompt
/// banner as its accessory. The free-form diary is `JournalPage(entry:)`
/// with no accessory; this is the thin screen for the prompted styles
/// (Emotional, Gratitude, Free-Flow, Replay Analysis).
struct EntryEditorView: View {
    let entry: JournalEntry

    var body: some View {
        JournalPage(entry: entry) {
            PromptBanner(entry: entry)
        }
    }
}

/// The style + session badge, the prompt, and a shuffle control — the
/// accessory slot `JournalPage` reserves under the date header.
private struct PromptBanner: View {
    let entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: entry.style.icon)
                    Text("\(entry.style.title) · \(entry.sessionLength.shortLabel)")
                        .textCase(.uppercase)
                }
                .font(.system(.caption, design: .serif).weight(.semibold))
                .foregroundStyle(Color.margin)

                Text(entry.prompt)
                    .font(.system(.title3, design: .serif).weight(.medium))
                    .foregroundStyle(Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                entry.prompt = PromptBank.random(for: entry.style, excluding: entry.prompt)
            } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(Color.ink)
                    .padding(8)
                    .background(Color.margin.opacity(0.15), in: Circle())
            }
            .accessibilityLabel("New prompt")
        }
    }
}
