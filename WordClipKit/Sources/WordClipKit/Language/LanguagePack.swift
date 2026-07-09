import Foundation

// MARK: - LanguagePack

/// 学习语言包协议。一个实现对应一种学习语言（英语、日语…）。
/// 注意：这与 App 界面语言（由系统语言决定）完全独立。
public protocol LanguagePack: Sendable {
    /// BCP-47 语言代码，如 "en"、"ja"
    var code: String { get }

    /// 用户可见名称（本地化），如 "English"、"日本語"
    var displayName: String { get }

    /// AVSpeechSynthesizer 使用的语言标识，如 "en-US"、"ja-JP"
    var ttsLanguage: String { get }

    /// 将一段文本分词，返回候选单词列表
    func tokenize(_ text: String) -> [String]
}

// MARK: - EnglishPack

/// 英语语言包。
public struct EnglishPack: LanguagePack {

    public let code = "en"
    public let displayName = "English"
    public let ttsLanguage = "en-US"

    public init() {}

    /// 英语：按空格/标点切分，取纯基本拉丁字母 token，过滤停用词和过短词。
    /// 仅收 a–z(用 isLatinLetter,排除 CJK 与带音标的拉丁扩展),
    /// 避免混合文本里中文/重音词漏入英文分词结果(与 WordTokenizer 一致)。
    public func tokenize(_ text: String) -> [String] {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)

        return text
            .components(separatedBy: separators)
            .map { $0.lowercased().trimmingCharacters(in: .letters.inverted) }
            .filter { $0.count >= 2 && $0.allSatisfy(\.isLatinLetter) }
            .filter { !Self.stopwords.contains($0) }
    }

    // 常见停用词，收集时自动过滤
    private static let stopwords: Set<String> = [
        "a", "an", "the", "is", "it", "in", "on", "at", "to", "of",
        "and", "or", "but", "for", "with", "as", "by", "be", "was",
        "are", "were", "has", "have", "had", "do", "does", "did",
        "will", "would", "can", "could", "may", "might", "shall",
        "should", "this", "that", "these", "those", "not", "no",
    ]
}
