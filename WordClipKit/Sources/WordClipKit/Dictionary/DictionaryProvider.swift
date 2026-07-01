import Foundation

// MARK: - DictionaryResult

public struct DictionaryResult: Sendable, Identifiable {
    /// 以查询词为标识（一次查词返回唯一结果），供 SwiftUI .sheet(item:) 等使用。
    public var id: String { word }
    public let word: String
    public let lemma: String?
    public let phonetic: String?
    public let definition: String?       // 中文释义
    public let definitionEn: String?     // 英英释义
    public let pos: String?              // 词性
    public let exchange: String?         // 变形（复数/过去式等）
    public let freqRank: Int?            // 词频排名（越小越常见）

    public init(
        word: String,
        lemma: String? = nil,
        phonetic: String? = nil,
        definition: String? = nil,
        definitionEn: String? = nil,
        pos: String? = nil,
        exchange: String? = nil,
        freqRank: Int? = nil
    ) {
        self.word = word
        self.lemma = lemma
        self.phonetic = phonetic
        self.definition = definition
        self.definitionEn = definitionEn
        self.pos = pos
        self.exchange = exchange
        self.freqRank = freqRank
    }
}

// MARK: - DictionaryProvider

/// 词库查询协议。实现与具体词库（SQLite / 网络 API 等）解耦。
public protocol DictionaryProvider: Sendable {
    /// 精确查词（小写化后查询）。
    func lookup(_ word: String) async -> DictionaryResult?

    /// 前缀补全建议，用于搜索框实时提示。
    func suggest(prefix: String, limit: Int) async -> [String]
}

// MARK: - NullDictionaryProvider

/// 开发期占位，始终返回 nil。
public struct NullDictionaryProvider: DictionaryProvider {
    public init() {}

    public func lookup(_ word: String) async -> DictionaryResult? { nil }
    public func suggest(prefix: String, limit: Int) async -> [String] { [] }
}
