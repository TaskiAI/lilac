import AVFoundation
import Observation

/// Records a voice note to a temporary `.m4a` file and publishes live state for
/// the Audio journal screen. Kept deliberately small: start/stop, an elapsed
/// clock, and a completion that hands back the finished file's URL + duration.
@Observable
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    enum Status { case idle, recording }

    private(set) var status: Status = .idle
    private(set) var elapsed: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var fileURL: URL?
    private var onFinish: ((URL, TimeInterval) -> Void)?

    /// Ask for microphone access (iOS 17 `AVAudioApplication` API).
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default)
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.record()

        self.recorder = recorder
        self.fileURL = url
        status = .recording
        elapsed = 0
        startTimer()
    }

    /// Stop recording; `completion` fires once the file is finalized on disk.
    func stop(completion: @escaping (URL, TimeInterval) -> Void) {
        guard status == .recording else { return }
        onFinish = completion
        recorder?.stop()
    }

    // MARK: AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        stopTimer()
        status = .idle
        let duration = elapsed
        if flag, let url = fileURL { onFinish?(url, duration) }
        onFinish = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    // MARK: Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder, recorder.isRecording else { return }
            self.elapsed = recorder.currentTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
