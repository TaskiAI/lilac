import SwiftUI
import PencilKit

/// The resurfaced-entry card: date, theme tags, an optional AI bridge sentence,
/// and three no-pressure actions. Every action closes the card — there is no
/// forced engagement and no modal trap.
struct RewindCard: View {
    let entry: JournalEntry
    let mode: RewindMode
    let bridge: String?
    let onReflect: () -> Void
    let onDismiss: () -> Void
    let onMute: () -> Void

    private var thumbnail: UIImage? {
        guard let drawing = try? PKDrawing(data: entry.drawingData),
              !drawing.bounds.isEmpty else { return nil }
        return drawing.image(from: drawing.bounds, scale: 1)
    }

    private var snippet: String {
        if let text = entry.text, !text.isEmpty { return text }
        if !entry.prompt.isEmpty { return entry.prompt }
        return entry.format?.title ?? "A past entry"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Rewind", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.lilac)
                    .textCase(.uppercase)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .accessibilityLabel("Not now")
            }

            Text(entry.createdAt.formatted(.dateTime.month(.wide).day().year()))
                .font(.headline)
                .foregroundStyle(.primary)

            if let bridge {
                Text(bridge)
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 12) {
                Text(snippet)
                    .font(.subheadline)
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(3)
                Spacer(minLength: 0)
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                        .background(Color.lilacSoft, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            if !entry.themeTags.isEmpty {
                ThemeTagRow(tags: entry.themeTags)
            }

            HStack(spacing: 10) {
                Button(action: onReflect) {
                    Text("Reflect now")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.lilac, in: Capsule())
                        .foregroundStyle(.white)
                }
                Button("Not now", action: onDismiss)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Menu {
                    Button("Mute this theme", systemImage: "bell.slash", action: onMute)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .accessibilityLabel("More options")
            }
        }
        .padding(16)
        .background(Color.lilacSoft, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// A wrapping row of theme-tag chips.
struct ThemeTagRow: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag.replacingOccurrences(of: "-", with: " "))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.lilac)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.lilac.opacity(0.12), in: Capsule())
            }
        }
    }
}

/// A minimal wrapping layout for tag chips (no external dependency).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0, rowHeight: CGFloat = 0, totalHeight: CGFloat = 0, totalWidth: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth - spacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - spacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
