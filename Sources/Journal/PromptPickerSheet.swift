import SwiftUI

/// Choose a writing prompt (or go blank) from the top of the writing page.
/// Grouped by style; picking sets the entry's prompt + style.
struct PromptPickerSheet: View {
    let onPick: (String, JournalStyle) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onClear()
                        dismiss()
                    } label: {
                        Label("Blank page — no prompt", systemImage: "doc")
                    }
                }

                ForEach(JournalStyle.allCases) { style in
                    Section {
                        ForEach(PromptBank.prompts(for: style).prefix(5), id: \.self) { prompt in
                            Button {
                                onPick(prompt, style)
                                dismiss()
                            } label: {
                                Text(prompt)
                                    .font(.system(.subheadline, design: .serif))
                                    .foregroundStyle(Color.homeHeading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    } header: {
                        Label(style.title, systemImage: style.icon)
                    }
                }
            }
            .navigationTitle("Choose a prompt")
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
