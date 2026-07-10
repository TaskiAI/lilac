import SwiftUI
import SwiftData

/// Schedule an upcoming session (or edit one). Purely the calendar side of the
/// feature — no audio; the writer records into it when the day comes. `session
/// == nil` creates a new scheduled session on save.
struct SessionScheduleForm: View {
    let session: TherapySession?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var therapist = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var showingRecord = false

    private var isRecorded: Bool { session?.hasRecording == true }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title (e.g. Weekly therapy)", text: $title)
                    TextField("With (therapist)", text: $therapist)
                    DatePicker("When", selection: $date)
                }
                Section("Notes") {
                    TextField("Anything to bring or remember…", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                if let session, !isRecorded {
                    Section {
                        Button {
                            showingRecord = true
                        } label: {
                            Label("Record this session now", systemImage: "mic.fill")
                        }
                    }
                    Section {
                        Button(role: .destructive, action: { delete(session) }) {
                            Label("Cancel session", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(session == nil ? "Schedule session" : "Edit session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty
                                  && therapist.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
            .sheet(isPresented: $showingRecord) {
                SessionRecordView(scheduled: session)
            }
        }
        .tint(.homeAccent)
    }

    private func load() {
        guard let session else { return }
        title = session.title
        therapist = session.therapistName
        date = session.date
        notes = session.notes
    }

    private func save() {
        let target = session ?? TherapySession(date: date, state: .scheduled)
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.therapistName = therapist.trimmingCharacters(in: .whitespaces)
        target.date = date
        target.notes = notes
        if session == nil { context.insert(target) }
        dismiss()
    }

    private func delete(_ session: TherapySession) {
        context.delete(session)
        dismiss()
    }
}
