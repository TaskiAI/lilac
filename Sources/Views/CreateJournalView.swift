import SwiftUI

/// The home screen's "Create" rail: a horizontal gallery of the non-writing
/// journaling formats. Each tile is a create button for that format; the
/// editors themselves are stubbed as `ComingSoonEditor` until they're built.
struct FormatGallery: View {
    let onSelect: (JournalFormat) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(JournalFormat.allCases) { format in
                    Button {
                        onSelect(format)
                    } label: {
                        FormatTile(format: format)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
}

private struct FormatTile: View {
    let format: JournalFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: format.icon)
                .font(.title2)
                .foregroundStyle(Color.lilac)
            Text(format.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(format.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if format.isAvailable {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.lilac)
            } else {
                Text("Soon")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.lilac)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.lilac.opacity(0.12), in: Capsule())
            }
        }
        .frame(width: 136, height: 156, alignment: .topLeading)
        .padding(14)
        .background(Color.lilacSoft, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Placeholder editor for a not-yet-built journaling format. It ships the entry
/// point (navigation, styling, the format's identity) now; the real editor
/// replaces this view later, one format at a time.
struct ComingSoonEditor: View {
    let format: JournalFormat
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: format.icon)
                    .font(.system(size: 56))
                    .foregroundStyle(Color.lilac)
                Text(format.title)
                    .font(.title.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(format.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Coming soon")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.lilac)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.lilac.opacity(0.12), in: Capsule())
                Spacer()
            }
            .padding(32)
            .frame(maxWidth: .infinity)
            .navigationTitle("Create")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
