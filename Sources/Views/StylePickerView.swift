import SwiftUI

/// Shown before every new entry: pick a journaling style, then a session
/// length. Together these decide which prompt pool the entry draws from
/// and the "dosage" badge shown while writing.
struct StylePickerView: View {
    let onPick: (JournalStyle, SessionLength) -> Void

    @State private var pendingStyle: JournalStyle?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(JournalStyle.allCases) { style in
                        Button {
                            pendingStyle = style
                        } label: {
                            StyleCard(style: style)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "How long do you want to write?",
                isPresented: Binding(
                    get: { pendingStyle != nil },
                    set: { if !$0 { pendingStyle = nil } }
                ),
                titleVisibility: .visible
            ) {
                ForEach(SessionLength.allCases) { length in
                    Button(length.label) {
                        if let style = pendingStyle {
                            onPick(style, length)
                        }
                        pendingStyle = nil
                    }
                }
                Button("Cancel", role: .cancel) { pendingStyle = nil }
            }
        }
    }
}

private struct StyleCard: View {
    let style: JournalStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: style.icon)
                .font(.title)
                .foregroundStyle(Color.lilac)
            Text(style.title)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(style.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .padding(16)
        .background(Color.lilacSoft, in: RoundedRectangle(cornerRadius: 16))
    }
}
