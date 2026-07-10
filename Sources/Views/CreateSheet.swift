import SwiftUI

/// Opened from the home orb: choose how to journal. Writing leads to its own
/// prompt choices (a blank "quick write" or a prompted style); the other formats
/// (audio, drawing, diagram, picture, log) start directly. Selections call back
/// to the host, which creates the entry and opens it on the main navigation.
struct CreateSheet: View {
    /// prompt (nil = blank) + style → start a writing entry.
    let onWriting: (String?, JournalStyle) -> Void
    /// start a non-writing format entry.
    let onFormat: (JournalFormat) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    NavigationLink {
                        WritingOptionsView(onPick: onWriting)
                    } label: {
                        CreateRow(
                            icon: "square.and.pencil",
                            title: "Writing",
                            subtitle: "Handwrite freely or from a prompt."
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(JournalFormat.allCases) { format in
                        Button { onFormat(format) } label: {
                            CreateRow(icon: format.icon, title: format.title, subtitle: format.subtitle)
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
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(.homeAccent)
    }
}

/// Writing's own prompt choices: a blank page (quick write) or a prompted style.
private struct WritingOptionsView: View {
    let onPick: (String?, JournalStyle) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Button { onPick(nil, .freeFlow) } label: {
                    CreateRow(
                        icon: "pencil.line",
                        title: "Blank page",
                        subtitle: "Just start writing — no prompt."
                    )
                }
                .buttonStyle(.plain)

                Text("Or start from a prompt")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.homeSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 6)

                ForEach(JournalStyle.allCases) { style in
                    Button { onPick(PromptBank.random(for: style), style) } label: {
                        CreateRow(icon: style.icon, title: style.title, subtitle: style.subtitle)
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
        .navigationTitle("Writing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CreateRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.homeAccent)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.homeTint))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.homeHeading)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.homeSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.homeSecondary.opacity(0.6))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .homeCardBackground()
    }
}
