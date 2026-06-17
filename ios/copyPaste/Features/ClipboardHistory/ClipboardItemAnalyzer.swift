import Foundation
import UIKit
import Vision

enum ClipboardItemAnalyzer {

    // MARK: - Category detection

    static func category(for text: String) -> ItemCategory {
        let detector = try? NSDataDetector(types:
            NSTextCheckingResult.CheckingType.link.rawValue |
            NSTextCheckingResult.CheckingType.phoneNumber.rawValue |
            NSTextCheckingResult.CheckingType.address.rawValue
        )
        let range = NSRange(text.startIndex..., in: text)
        let matches = detector?.matches(in: text, options: [], range: range) ?? []

        for match in matches {
            switch match.resultType {
            case .link:
                if let url = match.url {
                    return url.scheme == "mailto" ? .email : .url
                }
            case .phoneNumber:
                return .phone
            case .address:
                return .address
            default:
                break
            }
        }

        if looksLikeCode(text) { return .code }
        return .text
    }

    // MARK: - OCR

    static func extractText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation]
                else {
                    continuation.resume(returning: nil)
                    return
                }
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    // MARK: - Private

    private static func looksLikeCode(_ text: String) -> Bool {
        let codePatterns = [
            "func ", "var ", "let ", "class ", "struct ", "enum ", "import ",  // Swift/Kotlin
            "def ", "return ", "if ", "for ", "while ",                         // Python 等
            "function ", "const ", "=>", "===",                                 // JS
            "{", "}", "();", "//",                                              // 汎用記号
        ]
        let score = codePatterns.filter { text.contains($0) }.count
        return score >= 2
    }
}
