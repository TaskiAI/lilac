import Foundation

/// The structured content of a Log entry: a quick daily check-in — mood and
/// energy on a 1…5 scale, a few selected feelings, and a habit checklist. Kept
/// separate from the handwriting formats; persisted as JSON on the entry
/// (`JournalEntry.logData`, read/written via `moodLog`).
struct MoodLog: Codable, Equatable {
    var mood: Int          // 1 (low) … 5 (great)
    var energy: Int        // 1 (drained) … 5 (energized)
    var feelings: [String] // selected feeling chips
    var habits: [HabitCheck]

    init(
        mood: Int = 3,
        energy: Int = 3,
        feelings: [String] = [],
        habits: [HabitCheck] = MoodLog.defaultHabits
    ) {
        self.mood = mood
        self.energy = energy
        self.feelings = feelings
        self.habits = habits
    }

    /// The default checklist offered on a fresh Log entry.
    static let defaultHabits: [HabitCheck] = [
        "Slept well", "Moved my body", "Ate well",
        "Connected with someone", "Time outside", "Rested"
    ].map { HabitCheck(name: $0) }

    /// The feeling chips a writer can tag the day with.
    static let feelingOptions: [String] = [
        "Calm", "Happy", "Grateful", "Hopeful", "Content", "Proud",
        "Tired", "Anxious", "Sad", "Frustrated", "Lonely", "Overwhelmed"
    ]

    /// A face + label for each mood/energy level, for the 1…5 pickers.
    static func moodFace(_ level: Int) -> String {
        switch level {
        case 1: return "😞"
        case 2: return "🙁"
        case 3: return "😐"
        case 4: return "🙂"
        default: return "😄"
        }
    }

    static func moodLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Low"
        case 2: return "Meh"
        case 3: return "Okay"
        case 4: return "Good"
        default: return "Great"
        }
    }
}

/// One item in the habit checklist.
struct HabitCheck: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var done: Bool

    init(id: UUID = UUID(), name: String, done: Bool = false) {
        self.id = id
        self.name = name
        self.done = done
    }
}
