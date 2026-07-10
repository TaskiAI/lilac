import SwiftUI
import SwiftData

/// A read-only view of the AI transcript for a handwritten entry. The writing
/// stays ink on the page; this is a convenience — searchable, copyable text that
/// the on-device recognizer produced. Regenerates on open when missing or stale.
struct TranscriptView: View {
    @Bindable var entry: JournalEntry
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isWorking = false
    @State private var copied = false

    private var engine: TranscriptionEngine { TranscriptionEngine(context: context) }

    private var hasText: Bool {
        (entry.transcript?.isEmpty == false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isWorking && !hasText {
                        working
                    } else if hasText {
                        Text(entry.transcript ?? "")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Color.homeAccentDeep)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        empty
                    }

                    if entry.transcriptByteCount != nil, !entry.hasFreshTranscript, hasText {
                        Label("The ink changed since this was made — refresh to update.",
                              systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(Color.homeSecondary)
                    }

                    Text("On-device transcript — it may not be perfect. Your handwriting on the page is untouched.")
                        .font(.caption2)
                        .foregroundStyle(Color.homeSecondary)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .background(
                LinearGradient(colors: [.homeBackgroundTop, .homeBackgroundBottom],
                               startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            )
            .navigationTitle("Transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if hasText {
                        Button {
                            UIPasteboard.general.string = entry.transcript
                            copied = true
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        }
                        .accessibilityLabel("Copy transcript")
                    }
                    Button {
                        Task { await regenerate() }
                    } label: {
                        if isWorking { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(isWorking)
                    .accessibilityLabel("Regenerate transcript")
                }
            }
        }
        .tint(.homeAccent)
        .task {
            if entry.transcript == nil || !entry.hasFreshTranscript { await regenerate() }
        }
    }

    private var working: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Reading your handwriting…")
                .font(.subheadline)
                .foregroundStyle(Color.homeSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(Color.homeAccent)
            Text("No readable text yet")
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Color.homeAccentDeep)
            Text("Once there's handwriting on the page, tap refresh to transcribe it.")
                .font(.footnote)
                .foregroundStyle(Color.homeSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func regenerate() async {
        guard !isWorking else { return }
        isWorking = true
        copied = false
        await engine.transcribe(entry)
        isWorking = false
    }
}
