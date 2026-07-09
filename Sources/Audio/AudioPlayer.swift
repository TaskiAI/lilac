import AVFoundation
import Observation

/// Plays back a saved voice note. Publishes which clip is currently playing so a
/// row can show a play/stop state. One clip plays at a time.
@Observable
final class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var playingID: UUID?

    private var player: AVAudioPlayer?

    /// Toggle: play the clip, or stop it if it's already the one playing.
    func toggle(_ clip: AudioClip) {
        if playingID == clip.id {
            stop()
        } else {
            play(clip)
        }
    }

    func play(_ clip: AudioClip) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

            let player = try AVAudioPlayer(data: clip.data)
            player.delegate = self
            player.play()
            self.player = player
            playingID = clip.id
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
