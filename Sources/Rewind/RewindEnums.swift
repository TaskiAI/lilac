import Foundation

/// How often the scheduled rewind surfaces a past entry. `off` means the whole
/// pipeline is skipped — no candidate is ever generated (enforced in
/// `RewindSelector`, not just hidden in the UI).
enum RewindFrequency: String, CaseIterable, Identifiable, Codable {
    case off
    case weekly
    case biweekly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 weeks"
        }
    }

    /// Minimum days between rewinds. `nil` when off.
    var intervalDays: Int? {
        switch self {
        case .off: return nil
        case .weekly: return 7
        case .biweekly: return 14
        }
    }
}

/// How much the rewind leans in. `light` surfaces gentler, more recent, lower
/// salience entries; `deep` allows older, higher-salience ones.
enum RewindIntensity: String, CaseIterable, Identifiable, Codable {
    case light
    case deep

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "Light"
        case .deep: return "Deep"
        }
    }
}

/// The surfacing mode a rewind used. `sessionEcho` is stubbed behind a feature
/// flag until real therapy-session data exists (see `RewindEngine`).
enum RewindMode: String, CaseIterable, Identifiable, Codable {
    case theme
    case milestone
    case sessionEcho = "session_echo"
    case copingRetrospective = "coping_retrospective"

    var id: String { rawValue }
}

/// What the user did with a surfaced rewind.
enum RewindOutcome: String, Codable {
    case opened
    case dismissed
    case muted
    case reflected
}

/// The kind of DeepSeek call, for the audit log.
enum AICallKind: String, Codable {
    case tagging
    case safety
    case bridge
    case insight
}
