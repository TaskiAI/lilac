import Foundation

/// One recorded voice note in an Audio journal: the compressed audio bytes plus
/// how long it runs. The clips are persisted as a JSON-encoded array in
/// `JournalEntry.audioClips` (the bytes travel inside the clip), the same
/// pattern the Picture format uses for `CollageItem`.
struct AudioClip: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    /// AAC/m4a bytes as written by `AVAudioRecorder`.
    var data: Data
    var duration: TimeInterval
    var createdAt: Date = .now
}
