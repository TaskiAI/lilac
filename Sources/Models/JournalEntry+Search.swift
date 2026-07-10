import Foundation

extension JournalEntry {
    /// Lowercased text used for History search. Covers the text Lilac actually
    /// has on hand — prompt, typed/transcribed text, theme tags, Log feelings,
    /// format, and style — but NOT the handwriting ink (that would need
    /// persisted OCR). Computed on demand; nothing extra is stored.
    var searchHaystack: String {
        var parts: [String] = [prompt]
        if let text { parts.append(text) }
        parts.append(contentsOf: themeTags)
        if format == .log { parts.append(contentsOf: moodLog.feelings) }
        if let format { parts.append(format.title) }
        parts.append(style.title)
        return parts.joined(separator: " ").lowercased()
    }
}
