import Foundation

extension JournalEntry {
    /// Lowercased text used for History search: prompt, typed/transcribed text,
    /// the persisted handwriting transcript, theme tags, Log feelings, format,
    /// and style. Computed on demand.
    var searchHaystack: String {
        var parts: [String] = [prompt]
        if let title, !title.isEmpty { parts.append(title) }
        if let text { parts.append(text) }
        if let transcript, !transcript.isEmpty { parts.append(transcript) }
        parts.append(contentsOf: themeTags)
        if format == .log { parts.append(contentsOf: moodLog.feelings) }
        if let format { parts.append(format.title) }
        parts.append(style.title)
        return parts.joined(separator: " ").lowercased()
    }
}
