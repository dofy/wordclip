import AVFoundation

/// 单词朗读服务。用系统 AVSpeechSynthesizer，离线、跨平台。
@MainActor
final class Speaker {
    static let shared = Speaker()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    /// 朗读一个英文单词/短语。
    /// - Parameters:
    ///   - text: 要朗读的文本
    ///   - language: BCP-47 语言代码，默认美式英语
    func speak(_ text: String, language: String = "en-US") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 正在朗读则先停止，避免叠音
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }
}
