import Foundation
import SwiftData

/// The local equivalent of the spec's "backend job + API." It classifies
/// entries (tagging + safety) via DeepSeek, scores and maintains candidates,
/// and exposes the read/write operations the UI calls. Runs on the main actor
/// because it mutates the SwiftData context.
///
/// Safety posture (enforced here, not just documented):
/// - An entry is only ever eligible once its **safety** classification has run
///   (`crisisFlagged != nil`). A failed/timed-out safety call leaves it
///   unclassified so it is retried and never surfaced in the meantime.
/// - An entry with no recoverable text can't be screened, so it is marked
///   classified but left `crisisFlagged == nil` → excluded from candidacy.
/// - `crisisFlagged == true` entries never become passive candidates.
@MainActor
final class RewindEngine {
    /// No structured therapy-session data exists yet, so the `session_echo` mode
    /// stays behind this flag. TODO: enable once `sessions` are modeled.
    static let sessionEchoEnabled = false

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: Settings

    func settings() -> RewindSettings {
        if let existing = try? context.fetch(FetchDescriptor<RewindSettings>()).first {
            return existing
        }
        let created = RewindSettings()
        context.insert(created)
        return created
    }

    // MARK: The scheduled job

    /// Classify any pending entries and rebuild candidate scores. Skips entirely
    /// when the feature is off — the pipeline never runs, matching "respect
    /// `rewind_frequency = off` completely."
    func run() async {
        let settings = settings()
        guard settings.enabled, settings.frequency != .off else { return }
        await classifyPending()
        rebuildCandidates()
    }

    private func classifyPending() async {
        guard let entries = try? context.fetch(FetchDescriptor<JournalEntry>()) else { return }
        let pending = entries.filter { $0.classifiedAt == nil }.prefix(20)

        for entry in pending {
            let text = await entry.classifiableText()

            guard !text.isEmpty else {
                // Nothing to read (e.g. handwriting that didn't OCR). Mark it seen
                // but leave crisisFlagged nil → never a candidate (can't screen it).
                entry.classifiedAt = .now
                continue
            }

            if let tags = await RewindAI.tag(text: text) {
                entry.themeTags = tags.themes
                entry.salience = tags.salience
                log(.tagging, tags.prompt, tags.response)
            }

            guard let safety = await RewindAI.safety(text: text) else {
                // Couldn't screen — do NOT mark classified; retried next run, and
                // not eligible until then.
                continue
            }
            log(.safety, safety.prompt, safety.response)
            entry.crisisFlagged = safety.flagged
            entry.classifiedAt = .now
        }
    }

    private func rebuildCandidates() {
        guard let entries = try? context.fetch(FetchDescriptor<JournalEntry>()) else { return }
        // Only entries that were actually safety-screened are eligible.
        let eligible = entries.filter { $0.classifiedAt != nil && $0.crisisFlagged != nil }
        let existing = (try? context.fetch(FetchDescriptor<RewindCandidate>())) ?? []
        let intensity = settings().intensity

        for entry in eligible {
            let score = score(entry, among: eligible, intensity: intensity)
            if let candidate = existing.first(where: { $0.entry?.persistentModelID == entry.persistentModelID }) {
                candidate.salienceScore = score
                candidate.themeTags = entry.themeTags
                candidate.crisisFlagged = entry.crisisFlagged ?? false
                candidate.computedAt = .now
            } else {
                context.insert(RewindCandidate(
                    entry: entry,
                    salienceScore: score,
                    themeTags: entry.themeTags,
                    crisisFlagged: entry.crisisFlagged ?? false
                ))
            }
        }
    }

    // MARK: Selection (delegates guardrails to RewindSelector)

    struct Presentation {
        let candidate: RewindCandidate
        let entry: JournalEntry
        let mode: RewindMode
    }

    /// The next eligible rewind, or nil. All exclusion rules live in
    /// `RewindSelector`; this only maps models to/from it.
    func next() -> Presentation? {
        let settings = settings()
        let candidates = ((try? context.fetch(FetchDescriptor<RewindCandidate>())) ?? [])
            .filter { $0.entry != nil }
        guard !candidates.isEmpty else { return nil }

        let snapshots = candidates.map {
            RewindSelector.Candidate(
                salienceScore: $0.salienceScore,
                themeTags: $0.themeTags,
                crisisFlagged: $0.crisisFlagged,
                lastSurfaced: $0.lastSurfaced
            )
        }
        let settingsSnapshot = RewindSelector.Settings(
            enabled: settings.enabled,
            frequency: settings.frequency,
            mutedThemes: settings.mutedThemes,
            lastRewindAt: settings.lastRewindAt
        )
        guard let index = RewindSelector.select(from: snapshots, settings: settingsSnapshot) else {
            return nil
        }
        let candidate = candidates[index]
        guard let entry = candidate.entry else { return nil }
        return Presentation(candidate: candidate, entry: entry, mode: mode(for: entry))
    }

    /// Mark a rewind as shown — starts the frequency + 30-day recency clocks.
    func markShown(_ presentation: Presentation) {
        presentation.candidate.lastSurfaced = .now
        presentation.candidate.surfacedCount += 1
        settings().lastRewindAt = .now
    }

    /// Log the user's response. `muted` adds the entry's themes to the mute list.
    func record(_ presentation: Presentation, outcome: RewindOutcome) {
        context.insert(RewindSession(entry: presentation.entry, outcome: outcome, mode: presentation.mode))
        if outcome == .muted {
            let settings = settings()
            var muted = Set(settings.mutedThemes)
            muted.formUnion(presentation.entry.themeTags)
            settings.mutedThemes = Array(muted).sorted()
        }
    }

    func muteTheme(_ tag: String) {
        let settings = settings()
        var muted = Set(settings.mutedThemes)
        muted.insert(tag)
        settings.mutedThemes = Array(muted).sorted()
    }

    // MARK: Reflect + browse

    /// Create a new reflection linked back to the source entry. The reflection is
    /// a typed entry (its writing goes in `text`).
    @discardableResult
    func reflect(on source: JournalEntry, text: String = "") -> JournalEntry {
        let reflection = JournalEntry(
            prompt: "Reflecting on \(source.createdAt.formatted(.dateTime.month().day().year()))",
            style: source.style,
            text: text
        )
        reflection.linkedEntry = source
        context.insert(reflection)
        return reflection
    }

    /// All entries carrying a theme tag, oldest first — the Thread Revisit browse.
    /// Filtered in memory because the tags are JSON-encoded (no SQL to query).
    func entries(forTheme tag: String) -> [JournalEntry] {
        let entries = (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []
        return entries
            .filter { $0.themeTags.contains(tag) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// Opt-in only: crisis-flagged entries, newest first. Never touched by
    /// passive surfacing — only the confirmed "revisit hardest weeks" view calls
    /// this, and only after an explicit confirmation step in the UI.
    func hardestWeeks() -> [JournalEntry] {
        let entries = (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []
        return entries.filter { $0.crisisFlagged == true }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Distinct theme tags across all entries, most frequent first — for the
    /// browse picker.
    func allThemes() -> [String] {
        let entries = (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []
        var counts: [String: Int] = [:]
        for entry in entries {
            for tag in entry.themeTags { counts[tag, default: 0] += 1 }
        }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    /// The AI bridge sentence for a presentation; nil on any failure.
    func bridge(for entry: JournalEntry) async -> String? {
        let text = await entry.classifiableText()
        guard !text.isEmpty else { return nil }
        let moodNote = entry.salience.map { "emotional salience \(Int($0))/5" }
        guard let bridge = await RewindAI.bridge(pastText: text, pastDate: entry.createdAt, moodNote: moodNote) else {
            return nil
        }
        log(.bridge, bridge.prompt, bridge.response)
        return bridge.sentence
    }

    // MARK: Scoring + mode

    private func score(_ entry: JournalEntry, among entries: [JournalEntry], intensity: RewindIntensity) -> Double {
        let total = max(entries.count, 1)

        // Thematic recurrence: how often this entry's themes reappear elsewhere.
        let recurrence: Double = {
            guard !entry.themeTags.isEmpty else { return 0 }
            let shares = entry.themeTags.map { tag -> Double in
                let count = entries.filter { $0.themeTags.contains(tag) }.count
                return Double(count) / Double(total)
            }
            return shares.reduce(0, +) / Double(entry.themeTags.count)
        }()

        // Recency balance: peak for entries 1–12 months old, low if too recent.
        let ageDays = Calendar.current.dateComponents([.day], from: entry.createdAt, to: .now).day ?? 0
        let recency: Double = {
            switch ageDays {
            case ..<21: return 0.1
            case 21..<45: return 0.6
            case 45..<400: return 1.0
            default: return 0.5
            }
        }()

        let salience = (entry.salience ?? 3) / 5.0

        // Light leans on recency (gentler, nearer); deep leans on salience/age.
        let weights: (recurrence: Double, recency: Double, salience: Double) =
            intensity == .light ? (0.3, 0.5, 0.2) : (0.4, 0.25, 0.35)

        return weights.recurrence * recurrence
            + weights.recency * recency
            + weights.salience * salience
    }

    private func mode(for entry: JournalEntry) -> RewindMode {
        let ageDays = Calendar.current.dateComponents([.day], from: entry.createdAt, to: .now).day ?? 0
        let copingTags: Set<String> = ["coping", "recovery", "therapy", "self-care", "healing"]

        if (350...380).contains(ageDays) {
            return .milestone
        }
        if !Set(entry.themeTags).isDisjoint(with: copingTags) {
            return .copingRetrospective
        }
        // sessionEcho intentionally unreachable until sessions exist.
        return .theme
    }

    // MARK: Audit

    private func log(_ kind: AICallKind, _ prompt: String, _ response: String) {
        context.insert(AICallLog(kind: kind, prompt: prompt, response: response))
    }
}
