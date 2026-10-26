import AVFoundation
import Combine

/// 单词朗读服务。用系统 AVSpeechSynthesizer，离线、跨平台。
@MainActor
final class Speaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()

    @Published var voiceIdentifier: String {
        didSet { defaults.set(voiceIdentifier, forKey: "speech.voiceIdentifier") }
    }
    @Published var rateMultiplier: Double {
        didSet {
            let normalized = Self.normalizedRate(rateMultiplier)
            if rateMultiplier != normalized {
                rateMultiplier = normalized
                return
            }
            defaults.set(rateMultiplier, forKey: "speech.rateMultiplier")
        }
    }
    @Published private(set) var voices: [AVSpeechSynthesisVoice] = []
    @Published private(set) var isSpeaking = false

    private let defaults: UserDefaults
    private let synthesizer = AVSpeechSynthesizer()
    private var utteranceID: ObjectIdentifier?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        voiceIdentifier = defaults.string(forKey: "speech.voiceIdentifier") ?? ""
        rateMultiplier = Self.normalizedRate(defaults.object(forKey: "speech.rateMultiplier") as? Double ?? 0.9)
        super.init()
        synthesizer.delegate = self
        refreshVoices()
    }

    func refreshVoices() {
        voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.split(separator: "-").first == "en" }
            .sorted { voiceName($0).localizedStandardCompare(voiceName($1)) == .orderedAscending }
        if !voiceIdentifier.isEmpty, !voices.contains(where: { $0.identifier == voiceIdentifier }) {
            voiceIdentifier = ""
        }
    }

    func voiceName(_ voice: AVSpeechSynthesisVoice) -> String {
        let language = Locale.current.localizedString(forIdentifier: voice.language) ?? voice.language
        let quality: String
        switch voice.quality {
        case .enhanced:
            quality = String(localized: "settings.speech.enhanced", defaultValue: "Enhanced")
        case .premium:
            quality = String(localized: "settings.speech.premium", defaultValue: "Premium")
        default: quality = ""
        }
        return quality.isEmpty ? "\(voice.name) · \(language)" : "\(voice.name) · \(language) · \(quality)"
    }

    static func normalizedRate(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0.5), 1.5) : 0.9
    }

    func utterance(for text: String, language: String = "en-US") -> AVSpeechUtterance? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let utterance = AVSpeechUtterance(string: trimmed)
        let selected = voiceIdentifier.isEmpty ? nil : AVSpeechSynthesisVoice(identifier: voiceIdentifier)
        let family = language.split(separator: "-").first
        utterance.voice = selected?.language.split(separator: "-").first == family
            ? selected : AVSpeechSynthesisVoice(language: language)
        utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate,
                             max(AVSpeechUtteranceMinimumSpeechRate,
                                 AVSpeechUtteranceDefaultSpeechRate * Float(rateMultiplier)))
        return utterance
    }

    /// 朗读一个英文单词/短语。
    /// - Parameters:
    ///   - text: 要朗读的文本
    ///   - language: BCP-47 语言代码，默认美式英语
    func speak(_ text: String, language: String = "en-US") {
        guard let utterance = utterance(for: text, language: language) else { return }
        stop()
        utteranceID = ObjectIdentifier(utterance)
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        utteranceID = nil
        isSpeaking = false
        synthesizer.stopSpeaking(at: .immediate)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                      didFinish utterance: AVSpeechUtterance) {
        finished(ObjectIdentifier(utterance))
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                      didCancel utterance: AVSpeechUtterance) {
        finished(ObjectIdentifier(utterance))
    }

    private nonisolated func finished(_ id: ObjectIdentifier) {
        Task { @MainActor [weak self] in
            guard let self, utteranceID == id else { return }
            utteranceID = nil
            isSpeaking = false
        }
    }
}
