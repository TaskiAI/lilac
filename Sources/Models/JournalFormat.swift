import Foundation

/// A non-writing journaling format offered from the home screen's "Create"
/// gallery. The handwritten, prompted writing modes live under `JournalStyle`;
/// these are the other media — pictures, diagrams, audio, free sketching, and
/// structured logs. Every format now has a real editor.
enum JournalFormat: String, CaseIterable, Identifiable {
    case photo
    case diagram
    case audio
    case drawing
    case log

    var id: String { rawValue }

    var title: String {
        switch self {
        case .photo: return "Picture"
        case .diagram: return "Diagram"
        case .audio: return "Audio"
        case .drawing: return "Drawing"
        case .log: return "Log"
        }
    }

    var subtitle: String {
        switch self {
        case .photo: return "Collage photos into a page."
        case .diagram: return "Map ideas as nodes and links."
        case .audio: return "Speak your entry out loud."
        case .drawing: return "Sketch freely, no prompt."
        case .log: return "Track moods with sliders and checklists."
        }
    }

    var icon: String {
        switch self {
        case .photo: return "photo.on.rectangle.angled"
        case .diagram: return "point.3.connected.trianglepath.dotted"
        case .audio: return "waveform"
        case .drawing: return "scribble.variable"
        case .log: return "slider.horizontal.3"
        }
    }

    /// Whether the format has a real editor yet. Every format is now live.
    var isAvailable: Bool { true }
}
