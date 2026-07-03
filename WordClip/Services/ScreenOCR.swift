#if os(macOS)
import Foundation
import Vision
import CoreGraphics
import WordClipKit

/// 对截取的图像做文字识别，抽取候选英文单词。
enum ScreenOCR {

    /// 识别图像中的文字并返回去重、保序的候选英文单词。
    /// nonisolated：Vision 的回调在后台线程，不应绑定到 MainActor，
    /// 否则 `dispatch_assert_queue` 会因跨 actor 触发 SIGTRAP。
    static func recognizeWords(in image: CGImage) async -> [String] {
        let lines = await recognizeText(in: image)
        return WordTokenizer.extractWords(from: lines.joined(separator: " "))
    }

    /// 运行 Vision 文字识别，返回每行识别结果的最佳候选。
    private static func recognizeText(in image: CGImage) async -> [String] {
        await withCheckedContinuation { (cont: CheckedContinuation<[String], Never>) in
            // Vision 的 perform 同步阻塞，放到后台队列；回调与 resume 全程在后台线程，
            // 不触及任何 actor 隔离状态。
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { req, _ in
                    let observations = req.results as? [VNRecognizedTextObservation] ?? []
                    let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                    cont.resume(returning: lines)
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = ["en-US", "zh-Hans"]

                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    cont.resume(returning: [])
                }
            }
        }
    }
}
#endif
