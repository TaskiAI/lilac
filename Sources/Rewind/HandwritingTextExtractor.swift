import Vision
import PencilKit
import UIKit

/// Best-effort text recovery from a handwritten entry. Lilac's primary content
/// is ink (`PKDrawing`), not text, so classification has nothing to read unless
/// we recognize it.
///
/// Two backends, picked at runtime:
/// - **Google ML Kit Digital Ink** (`MLKitHandwritingRecognizer`) when the pod
///   is present — stroke-based, on-device, far better on real handwriting.
/// - **Apple Vision** OCR otherwise — image-based, weaker, but zero-dependency
///   so the app always builds and works.
enum HandwritingTextExtractor {
    static func text(from drawingData: Data) async -> String {
        guard let drawing = try? PKDrawing(data: drawingData), !drawing.bounds.isEmpty else {
            return ""
        }

        #if canImport(MLKitDigitalInkRecognition)
        if let recognized = await MLKitHandwritingRecognizer.shared.recognize(drawing),
           !recognized.isEmpty {
            return recognized
        }
        #endif

        return await visionText(from: drawing)
    }

    /// Apple Vision OCR fallback. Renders the ink and runs text recognition; note
    /// this is tuned for print, so cursive results are unreliable.
    private static func visionText(from drawing: PKDrawing) async -> String {
        guard let cgImage = drawing.image(from: drawing.bounds, scale: 2).cgImage else { return "" }
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ") ?? ""
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}

extension JournalEntry {
    /// The text used to classify this entry: the prompt (context), any typed or
    /// transcribed text, and recognized handwriting. May be empty/partial for a
    /// handwritten entry whose ink didn't recognize.
    func classifiableText() async -> String {
        var parts: [String] = []
        if !prompt.isEmpty { parts.append("Prompt: \(prompt)") }
        if let text, !text.isEmpty { parts.append(text) }
        let ink = await HandwritingTextExtractor.text(from: drawingData)
        if !ink.isEmpty { parts.append(ink) }
        return parts.joined(separator: "\n")
    }
}
