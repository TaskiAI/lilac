import SwiftUI
import SwiftData

/// The Sessions tab: the therapist-session assistant. A calendar strip of
/// upcoming sessions sits up top, the recorded sessions list below, and a docked
/// bar at the bottom carries the AI companion chatbox plus a glowing record orb
/// for capturing a new session.
struct SessionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TherapySession.date, order: .reverse) private var sessions: [TherapySession]

    @State private var showingRecord = false
    @State private var showingCompanion = false
    @State private var scheduling: TherapySession?
    @State private var showingSchedule = false
    @State private var selected: TherapySession?

    private var upcoming: [TherapySession] {
        sessions
            .filter { !$0.hasRecording && $0.date >= Calendar.current.startOfDay(for: .now) }
            .sorted { $0.date < $1.date }
    }

    private var recorded: [TherapySession] {
        sessions.filter(\.hasRecording) // already newest-first from the query
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    UpcomingCalendar(
                        sessions: upcoming,
                        onSchedule: { showingSchedule = true },
                        onOpen: { scheduling = $0 }
                    )
                    recordedSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(
                LinearGradient(
                    colors: [.homeBackgroundTop, .homeBackgroundBottom],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationBarHidden(true)
            .navigationDestination(item: $selected) { SessionDetailView(session: $0) }
            .safeAreaInset(edge: .bottom) { bottomDock }
            .sheet(isPresented: $showingRecord) { SessionRecordView() }
            .sheet(isPresented: $showingCompanion) { CompanionView() }
            .sheet(isPresented: $showingSchedule) { SessionScheduleForm(session: nil) }
            .sheet(item: $scheduling) { SessionScheduleForm(session: $0) }
        }
        .tint(.homeAccent)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Sessions")
                .font(.system(size: 27, weight: .bold, design: .serif))
                .foregroundStyle(Color.homeHeading)
            Text("Record your therapy sessions and revisit what was said.")
                .font(.subheadline)
                .foregroundStyle(Color.homeSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Recorded list

    @ViewBuilder
    private var recordedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recorded")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.homeSecondary)

            if recorded.isEmpty {
                emptyRecorded
            } else {
                VStack(spacing: 10) {
                    ForEach(recorded) { session in
                        Button { selected = session } label: {
                            SessionRow(session: session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyRecorded: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.homeTint).frame(width: 72, height: 72)
                Image(systemName: "waveform")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.homeAccent)
            }
            Text("No sessions recorded yet")
                .font(.system(.subheadline, design: .serif).weight(.medium))
                .foregroundStyle(Color.homeAccentDeep)
            Text("Tap the orb to record a session. It's transcribed with speakers and summarized for you.")
                .font(.caption)
                .foregroundStyle(Color.homeSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .homeCardBackground()
    }

    // MARK: Bottom dock — companion chatbox + record orb

    private var bottomDock: some View {
        HStack(spacing: 12) {
            Button { showingCompanion = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(Color.homeAccent)
                    Text("Ask your companion…")
                        .font(.subheadline)
                        .foregroundStyle(Color.homeSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.homeCard)
                        .overlay(Capsule().stroke(Color.homeHairline, lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            Button { showingRecord = true } label: {
                GlowOrbView(size: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Record a session")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Upcoming calendar strip

private struct UpcomingCalendar: View {
    let sessions: [TherapySession]
    let onSchedule: () -> Void
    let onOpen: (TherapySession) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.homeHeading)
                Spacer()
                Button(action: onSchedule) {
                    Label("Schedule", systemImage: "calendar.badge.plus")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.homeAccent)
                }
            }

            if sessions.isEmpty {
                Text("Nothing scheduled. Add your next appointment to keep track.")
                    .font(.caption)
                    .foregroundStyle(Color.homeSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(sessions) { session in
                            Button { onOpen(session) } label: { UpcomingChip(session: session) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .homeCardBackground()
    }
}

private struct UpcomingChip: View {
    let session: TherapySession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(Color.homeAccent)
            Text(session.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.homeAccentDeep)
            Text(session.title.isEmpty ? "Session" : session.title)
                .font(.caption)
                .foregroundStyle(Color.homeHeading)
                .lineLimit(1)
            Text(session.date.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(Color.homeSecondary)
        }
        .padding(12)
        .frame(width: 132, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.homeTint))
    }
}

// MARK: - Recorded row

private struct SessionRow: View {
    let session: TherapySession

    private var name: String {
        session.title.isEmpty ? "Therapy session" : session.title
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.homeTint).frame(width: 44, height: 44)
                Image(systemName: "waveform")
                    .font(.subheadline)
                    .foregroundStyle(Color.homeAccent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(.body, design: .serif).weight(.medium))
                    .foregroundStyle(Color.homeHeading)
                HStack(spacing: 8) {
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    if session.duration > 0 {
                        Text("· \(SessionRecordView.durationText(session.duration))")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color.homeSecondary)
            }
            Spacer(minLength: 4)
            StateBadge(state: session.state)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .homeCardBackground()
    }
}

/// A small pill showing where a session is in processing.
struct StateBadge: View {
    let state: SessionState

    var body: some View {
        switch state {
        case .transcribing:
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                Text("Transcribing")
            }
            .font(.caption2)
            .foregroundStyle(Color.homeSecondary)
        case .ready:
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.homeSecondary.opacity(0.5))
        case .failed:
            Label("Retry", systemImage: "exclamationmark.arrow.circlepath")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .scheduled:
            EmptyView()
        }
    }
}
