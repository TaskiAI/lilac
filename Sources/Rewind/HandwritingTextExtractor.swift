import Vision
import PencilKit
import UIKit

/// Best-effort text recovery from a handwritten entry. Lilac's primary content
/// is ink (`PKDrawing`), not text, so classification has nothing to read unless
/// we OCR it. Vision's handwriting recognition is imperfect — treat the result
/// as a hint, never as ground truth (see the safety caveat in `RewindEngine`).
enum HandwritingTextExtractor {
    static func text(from drawingData: Data) async -> String {
        guard let drawing = try? PKDrawing(data: drawingData), !drawing.bounds.isEmpty,
              let cgImage = drawing.image(from: drawing.bounds, scale: 2).cgImage else {
            return ""
        }
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
    /// transcribed text, and OCR of the handwriting. May be empty/partial for a
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
