import SwiftUI
import SwiftData

/// The Meetings tab: a local record of sessions — therapy, check-ins, support
/// circles — split into upcoming and past, with notes to bring and take away.
struct MeetingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Meeting.date, order: .forward) private var meetings: [Meeting]

    @State private var editing: Meeting?
    @State private var showingNew = false

    private var upcoming: [Meeting] {
        meetings.filter { $0.date >= Calendar.current.startOfDay(for: .now) }
    }
    private var past: [Meeting] {
        meetings.filter { $0.date < Calendar.current.startOfDay(for: .now) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if meetings.isEmpty {
                    emptyState
                } else {
                    List {
                        if !upcoming.isEmpty {
                            Section("Upcoming") {
                                ForEach(upcoming) { row($0) }
                                    .onDelete { delete(upcoming, at: $0) }
                            }
                        }
                        if !past.isEmpty {
                            Section("Past") {
                                ForEach(past) { row($0) }
                                    .onDelete { delete(past, at: $0) }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(
                LinearGradient(
                    colors: [.homeBackgroundTop, .homeBackgroundBottom],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Meetings")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNew = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New meeting")
                }
            }
            .sheet(isPresented: $showingNew) {
                MeetingFormView(meeting: nil)
            }
            .sheet(item: $editing) { meeting in
                MeetingFormView(meeting: meeting)
            }
        }
        .tint(.homeAccent)
    }

    private func row(_ meeting: Meeting) -> some View {
        Button {
            editing = meeting
        } label: {
            MeetingRow(meeting: meeting)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Color.homeTint).frame(width: 96, height: 96)
                Image(systemName: "person.2")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.homeAccent)
            }
            Text("No meetings yet")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(Color.homeAccentDeep)
            Text("Keep track of therapy sessions and check-ins with people you trust.")
                .font(.subheadline)
                .foregroundStyle(Color.homeSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                showingNew = true
            } label: {
                Label("Add a meeting", systemImage: "plus")
                    .font(.system(.subheadline, design: .serif).weight(.medium))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Color.homeAccent))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func delete(_ list: [Meeting], at offsets: IndexSet) {
        for index in offsets { context.delete(list[index]) }
    }
}

private struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 0) {
                Text(meeting.date.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.homeAccent)
                Text(meeting.date.formatted(.dateTime.day()))
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.homeAccentDeep)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(meeting.title.isEmpty ? "Meeting" : meeting.title)
                    .font(.system(.body, design: .serif).weight(.medium))
                    .foregroundStyle(Color.homeAccentDeep)
                HStack(spacing: 8) {
                    if !meeting.personName.isEmpty {
                        Label(meeting.personName, systemImage: "person")
                    }
                    Label(meeting.date.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(Color.homeSecondary)
                .labelStyle(.titleAndIcon)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.homeSecondary.opacity(0.6))
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

/// Add or edit a meeting. `meeting == nil` creates a new one on save.
private struct MeetingFormView: View {
    let meeting: Meeting?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var personName = ""
    @State private var date = Date()
    @State private var location = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title (e.g. Therapy session)", text: $title)
                    TextField("With (name)", text: $personName)
                    DatePicker("When", selection: $date)
                    TextField("Location or link", text: $location)
                }
                Section("Notes") {
                    TextField("Anything to bring or remember…", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
                if meeting != nil {
                    Section {
                        Button(role: .destructive, action: deleteMeeting) {
                            Label("Delete meeting", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(meeting == nil ? "New meeting" : "Edit meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty
                                  && personName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
        .tint(.homeAccent)
    }

    private func load() {
        guard let meeting else { return }
        title = meeting.title
        personName = meeting.personName
        date = meeting.date
        location = meeting.location
        notes = meeting.notes
    }

    private func save() {
        let target = meeting ?? Meeting()
        target.title = title
        target.personName = personName
        target.date = date
        target.location = location
        target.notes = notes
        if meeting == nil { context.insert(target) }
        dismiss()
    }

    private func deleteMeeting() {
        if let meeting { context.delete(meeting) }
        dismiss()
    }
}
