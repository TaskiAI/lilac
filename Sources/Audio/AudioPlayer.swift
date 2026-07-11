import AVFoundation
import Observation

/// Plays back a saved voice note. Publishes which clip is currently playing so a
/// row can show a play/stop state. One clip plays at a time.
@Observable
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var playingID: UUID?

    private var player: AVAudioPlayer?

    /// Toggle playback of an on-disk file (recorded Sessions store audio on disk).
    /// `id` identifies the source so a row can reflect play/stop state.
    func toggle(url: URL, id: UUID) {
        if playingID == id { stop() } else { play(url: url, id: id) }
    }

    func play(url: URL, id: UUID) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.play()
            self.player = player
            playingID = id
        } catch {
            playingID = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playingID = nil
    }
}
