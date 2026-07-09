import Foundation

/// The journaling style chosen for an entry. Each style has its own prompt
/// pool and framing, matching the core styles from the journaling research:
/// emotional-experience writing, gratitude writing, free-flow ("canoe")
/// writing, and replay-analysis reflection.
enum JournalStyle: String, Codable, CaseIterable, Identifiable {
    case emotional
    case gratitude
    case freeFlow
    case replayAnalysis

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emotional: return "Emotional"
        case .gratitude: return "Gratitude"
        case .freeFlow: return "Free-Flow"
        case .replayAnalysis: return "Replay Analysis"
        }
    }

    var subtitle: String {
        switch self {
        case .emotional:
            return "Write through a moment that hit hard, good or bad."
        case .gratitude:
            return "Note what you're thankful for and who made it better."
        case .freeFlow:
            return "Start with a topic and let your mind wander wherever it goes."
        case .replayAnalysis:
            return "Replay your day like game footage and catch what you missed."
        }
    }

    var icon: String {
        switch self {
        case .emotional: return "heart.circle"
        case .gratitude: return "sun.max"
        case .freeFlow: return "water.waves"
        case .replayAnalysis: return "arrow.counterclockwise.circle"
        }
    }
}

/// How much time the writer intends to spend, echoing the "dosage" framing
/// from the journaling research (short daily check-ins vs. longer weekly
/// sessions). Purely a badge/intent for now — no reminders attached.
enum SessionLength: String, Codable, CaseIterable, Identifiable {
    case quick
    case deep

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quick: return "Quick · 15 min"
        case .deep: return "Deep · 30-60 min"
        }
    }

    var shortLabel: String {
        switch self {
        case .quick: return "15 min"
        case .deep: return "30-60 min"
        }
    }
}
