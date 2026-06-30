import Foundation

// MARK: - WordBackup

/// 词库备份的可序列化容器。与 SwiftData `@Model` 解耦，用于 JSON 导出/导入。
/// `version` 字段为未来格式升级 / 真同步预留。
public struct WordBackup: Codable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var exportedAt: Date
    public var words: [WordDTO]

    public init(version: Int = WordBackup.currentVersion, exportedAt: Date, words: [WordDTO]) {
        self.version = version
        self.exportedAt = exportedAt
        self.words = words
    }
}

// MARK: - WordDTO

/// 单个词条的可序列化快照。只含迁移必需字段，
/// 不含 CollectSource 完整记录和 ReviewLog（减小体积，迁移非必需）。
public struct WordDTO: Codable, Sendable {
    public var headword: String
    public var lemma: String
    public var language: String
    public var definition: String?
    public var definitionEn: String?
    public var phonetic: String?
    public var tags: [String]
    public var createdAt: Date
    public var isFavorite: Bool

    // 复习状态（SM-2）
    public var familiarity: Int
    public var easeFactor: Double
    public var interval: Int
    public var repetitions: Int
    public var dueAt: Date?
    public var lastReviewedAt: Date?

    public init(
        headword: String, lemma: String, language: String,
        definition: String?, definitionEn: String?, phonetic: String?,
        tags: [String], createdAt: Date, isFavorite: Bool,
        familiarity: Int, easeFactor: Double, interval: Int, repetitions: Int,
        dueAt: Date?, lastReviewedAt: Date?
    ) {
        self.headword = headword
        self.lemma = lemma
        self.language = language
        self.definition = definition
        self.definitionEn = definitionEn
        self.phonetic = phonetic
        self.tags = tags
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.familiarity = familiarity
        self.easeFactor = easeFactor
        self.interval = interval
        self.repetitions = repetitions
        self.dueAt = dueAt
        self.lastReviewedAt = lastReviewedAt
    }
}

// MARK: - WordEntry 映射

extension WordDTO {
    /// 从 SwiftData 模型构造 DTO。
    public init(entry: WordEntry) {
        self.init(
            headword: entry.headword,
            lemma: entry.lemma,
            language: entry.language,
            definition: entry.definition,
            definitionEn: entry.definitionEn,
            phonetic: entry.phonetic,
            tags: entry.tags,
            createdAt: entry.createdAt,
            isFavorite: entry.isFavorite,
            familiarity: entry.familiarity,
            easeFactor: entry.easeFactor,
            interval: entry.interval,
            repetitions: entry.repetitions,
            dueAt: entry.dueAt,
            lastReviewedAt: entry.lastReviewedAt
        )
    }
}

extension WordBackup {
    /// 从一组 WordEntry 构造备份容器。exportedAt 由调用方传入（便于测试 / 避免裸 Date()）。
    public static func from(entries: [WordEntry], exportedAt: Date) -> WordBackup {
        WordBackup(
            exportedAt: exportedAt,
            words: entries.map(WordDTO.init(entry:))
        )
    }
}
