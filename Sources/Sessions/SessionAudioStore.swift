import Foundation

/// On-disk storage for recorded session audio. Therapy sessions run long (tens
/// of minutes → several MB of AAC), which is too large to keep inline in a
/// SwiftData blob the way short `AudioClip`s are; so the bytes live as files in
/// Application Support and `TherapySession` keeps only the filename.
enum SessionAudioStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Sessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Persist `data` under a fresh filename and return it (nil on failure).
    static func save(data: Data) -> String? {
        let name = UUID().uuidString + ".m4a"
        do {
            try data.write(to: directory.appendingPathComponent(name))
            return name
        } catch {
            return nil
        }
    }

    /// The on-disk URL for a stored filename (whether or not it exists yet).
    static func url(for filename: String) -> URL {
        directory.appendingPathComponent(filename)
    }

    static func exists(_ filename: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: filename).path)
    }

    static func delete(_ filename: String) {
        try? FileManager.default.removeItem(at: url(for: filename))
    }
}
