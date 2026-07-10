#if canImport(MLKitDigitalInkRecognition)
import MLKitDigitalInkRecognition
import PencilKit
import Foundation

/// Google ML Kit Digital Ink Recognition backend — the preferred handwriting
/// engine. Stroke-based (fed from `PKStroke` points, not a rendered image) and
/// fully on-device once the language model has downloaded.
///
/// This file only compiles when the `GoogleMLKit/DigitalInkRecognition` pod is
/// present (see the repo `Podfile`); `HandwritingTextExtractor` falls back to
/// Vision otherwise. NOTE: the specific ML Kit API surface here should be
/// double-checked against the installed pod version on a Mac.
final class MLKitHandwritingRecognizer {
    static let shared = MLKitHandwritingRecognizer()

    private let model: DigitalInkRecognitionModel?
    private let recognizer: DigitalInkRecognizer?
    private let modelManager = ModelManager.modelManager()

    init(languageTag: String = "en-US") {
        if let identifier = try? DigitalInkRecognitionModelIdentifier(forLanguageTag: languageTag) {
            let model = DigitalInkRecognitionModel(modelIdentifier: identifier)
            self.model = model
            self.recognizer = DigitalInkRecognizer.digitalInkRecognizer(
                options: DigitalInkRecognizerOptions(model: model)
            )
        } else {
            self.model = nil
            self.recognizer = nil
        }
    }

    /// Recognize a drawing to text, or nil if the model/recognizer isn't ready.
    func recognize(_ drawing: PKDrawing) async -> String? {
        guard let recognizer, !drawing.strokes.isEmpty, await ensureModelDownloaded() else {
            return nil
        }
        let ink = Self.ink(from: drawing)
        return await withCheckedContinuation { continuation in
            recognizer.recognize(ink: ink) { result, _ in
                continuation.resume(returning: result?.candidates.first?.text)
            }
        }
    }

    /// Download the language model once (on-device thereafter). Uses the ML Kit
    /// success/failure notifications to bridge to async.
    private func ensureModelDownloaded() async -> Bool {
        guard let model else { return false }
        if modelManager.isModelDownloaded(model) { return true }

        return await withCheckedContinuation { continuation in
            let center = NotificationCenter.default
            var resumed = false
            var tokens: [NSObjectProtocol] = []
            let finish: (Bool) -> Void = { success in
                guard !resumed else { return }
                resumed = true
                tokens.forEach(center.removeObserver)
                continuation.resume(returning: success)
            }
            tokens.append(center.addObserver(forName: .mlkitModelDownloadDidSucceed, object: nil, queue: .main) { _ in
                finish(true)
            })
            tokens.append(center.addObserver(forName: .mlkitModelDownloadDidFail, object: nil, queue: .main) { _ in
                finish(false)
            })
            modelManager.download(
                model,
                conditions: ModelDownloadConditions(allowsCellularAccess: true, allowsBackgroundDownloading: true)
            )
        }
    }

    /// Convert a `PKDrawing` into ML Kit `Ink`: each stroke's control points,
    /// mapped from path space into canvas space, with millisecond timestamps.
    private static func ink(from drawing: PKDrawing) -> Ink {
        let strokes: [Stroke] = drawing.strokes.map { pkStroke in
            let transform = pkStroke.transform
            let path = pkStroke.path
            var points: [StrokePoint] = []
            points.reserveCapacity(path.count)
            for index in 0..<path.count {
                let point = path[index]
                let location = point.location.applying(transform)
                points.append(StrokePoint(
                    x: Float(location.x),
                    y: Float(location.y),
                    t: Int(point.timeOffset * 1000)
                ))
            }
            return Stroke(points: points)
        }
        return Ink(strokes: strokes)
    }
}
#endif
