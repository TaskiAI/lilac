import SwiftUI

/// Opened from the home orb: choose how to journal. Every option goes straight
/// to its journaling page — Writing opens a blank page whose prompt picker lives
/// at the top of the page, and the other formats open their editor directly.
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
                    Button { onWriting(nil, .freeFlow) } label: {
                        CreateRow(
                            icon: "square.and.pencil",
                            title: "Writing",
                            subtitle: "Handwrite freely, or pick a prompt on the page."
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
