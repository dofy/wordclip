import Foundation
import SwiftData

// MARK: - WordEntry

/// 用户词典中的一个词条。
/// CloudKit 建模约束：所有属性有默认值或可选，不使用 @Attribute(.unique)（去重在应用层完成）。
@Model
public final class WordEntry {

    public var id: UUID
    public var headword: String        // 用户收集时的原始形态
    public var lemma: String           // 归一化词元（小写，用于查词/去重）
    public var language: String        // 语言代码："en" / "ja" 等
    public var definition: String?     // 缓存的中文释义
    public var definitionEn: String?   // 缓存的英英释义
    public var phonetic: String?       // IPA 音标
    public var tags: [String]
    public var createdAt: Date
    public var isFavorite: Bool

    // MARK: 复习状态（SM-2）
    public var familiarity: Int        // 0–5，0 = 未学，5 = 完全掌握
    public var easeFactor: Double      // SM-2 EF，初始 2.5
    public var interval: Int           // 距下次复习的天数
    public var repetitions: Int        // 连续答对次数
    public var dueAt: Date?
    public var lastReviewedAt: Date?

    // MARK: 收集来源（一个词可多次被收集）
    @Relationship(deleteRule: .cascade)
    public var sources: [CollectSource]

    public init(
        headword: String,
        lemma: String,
        language: String = "en"
    ) {
        self.id = UUID()
        self.headword = headword
        self.lemma = lemma
        self.language = language
        self.tags = []
        self.createdAt = Date()
        self.isFavorite = false
        self.familiarity = 0
        self.easeFactor = 2.5
        self.interval = 0
        self.repetitions = 0
        self.sources = []
    }
}

// MARK: - CollectSource

/// 单次收集事件：记录在哪里、什么时候收集到了这个词。
@Model
public final class CollectSource {

    public var id: UUID
    public var collectedAt: Date
    public var platform: String        // "macOS" / "iOS"
    public var appName: String?        // 来源 App 名称（macOS 可通过 Accessibility 获取）
    public var contextSentence: String? // 收集时的原句（若可捕获）
    public var bundleIdentifier: String?

    public init(
        platform: String,
        appName: String? = nil,
        contextSentence: String? = nil,
        bundleIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.collectedAt = Date()
        self.platform = platform
        self.appName = appName
        self.contextSentence = contextSentence
        self.bundleIdentifier = bundleIdentifier
    }
}

// MARK: - ReviewLog

/// 每次测试的记录，用于统计和未来 FSRS 训练数据。
@Model
public final class ReviewLog {

    public var id: UUID
    public var date: Date
    public var wordID: UUID
    public var grade: Int              // 0–5（SM-2 评分）
    public var mode: ReviewMode
    public var responseTimeMs: Int?    // 答题用时（毫秒）

    public init(wordID: UUID, grade: Int, mode: ReviewMode, responseTimeMs: Int? = nil) {
        self.id = UUID()
        self.date = Date()
        self.wordID = wordID
        self.grade = grade
        self.mode = mode
        self.responseTimeMs = responseTimeMs
    }
}

// MARK: - Supporting Types

public enum ReviewMode: String, Codable, CaseIterable, Sendable {
    case multipleChoice   // 英 → 中 选择
    case spelling         // 中 → 英 拼写
    case listening        // 听音辨义
}
