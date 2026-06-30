import Testing
import Foundation
@testable import WordClipKit

// MARK: - SM2 Engine Tests

@Suite("SM2Engine")
struct SM2EngineTests {

    let engine = SM2Engine()
    let now = Date()

    @Test("初始状态答对 5 次，熟悉度升至 5")
    func correctAnswersIncreaseFamiliarity() {
        var state = ReviewState.initial
        for grade in [5, 5, 5, 5, 5] {
            let (next, _) = engine.schedule(state, grade: grade, now: now)
            state = next
        }
        #expect(state.familiarity == 5)
    }

    @Test("答错（grade < 3）重置重复次数和间隔")
    func wrongAnswerResetsRepetitions() {
        var state = ReviewState.initial
        // 先答对两次
        (state, _) = engine.schedule(state, grade: 5, now: now)
        (state, _) = engine.schedule(state, grade: 5, now: now)
        #expect(state.repetitions == 2)
        // 再答错
        let (reset, _) = engine.schedule(state, grade: 1, now: now)
        #expect(reset.repetitions == 0)
        #expect(reset.interval == 1)
    }

    @Test("EaseFactor 不低于 1.3")
    func easeFactorFloor() {
        var state = ReviewState.initial
        // 连续低分
        for _ in 0..<10 {
            (state, _) = engine.schedule(state, grade: 0, now: now)
        }
        #expect(state.easeFactor >= 1.3)
    }

    @Test("高分答对后间隔递增")
    func intervalGrowsWithCorrectAnswers() {
        var state = ReviewState.initial
        var intervals: [Int] = []
        for _ in 0..<5 {
            let (next, _) = engine.schedule(state, grade: 5, now: now)
            intervals.append(next.interval)
            state = next
        }
        // 间隔应该整体递增（允许有轻微波动，但不能连续下降）
        let isGenerallyIncreasing = zip(intervals, intervals.dropFirst())
            .filter { $0 > $1 }.count <= 1
        #expect(isGenerallyIncreasing)
    }

    @Test("dueAt 在 now 之后的 interval 天")
    func dueAtIsCorrect() {
        let (state, dueAt) = engine.schedule(.initial, grade: 5, now: now)
        let expectedDue = Calendar.current.date(byAdding: .day, value: state.interval, to: now)!
        let diff = abs(dueAt.timeIntervalSince(expectedDue))
        #expect(diff < 1)  // 误差 < 1 秒
    }
}

// MARK: - EnglishPack Tests

@Suite("EnglishPack")
struct EnglishPackTests {

    let pack = EnglishPack()

    @Test("分词过滤停用词")
    func tokenizeFiltersStopwords() {
        let tokens = pack.tokenize("The quick brown fox jumps over the lazy dog")
        #expect(!tokens.contains("the"))
        #expect(tokens.contains("quick"))
        #expect(tokens.contains("fox"))
    }

    @Test("分词过滤单字母")
    func tokenizeFiltersSingleChars() {
        let tokens = pack.tokenize("a cat and a dog")
        #expect(!tokens.contains("a"))
        #expect(tokens.contains("cat"))
        #expect(tokens.contains("dog"))
    }

    @Test("分词处理标点")
    func tokenizeHandlesPunctuation() {
        let tokens = pack.tokenize("Hello, world! It's a beautiful day.")
        #expect(tokens.contains("hello"))
        #expect(tokens.contains("world"))
        #expect(tokens.contains("beautiful"))
    }
}

// MARK: - MockEntitlement Tests

@Suite("MockEntitlement")
@MainActor
struct MockEntitlementTests {

    @Test("默认非 Pro")
    func defaultIsNotPro() {
        let mock = MockEntitlement()
        #expect(!mock.isPro)
    }

    @Test("overridePro=true 时 isPro 为 true")
    func overrideProIsTrue() {
        let mock = MockEntitlement(overridePro: true)
        #expect(mock.isPro)
    }

    @Test("purchase 后 isPro 变为 true")
    func purchaseSetsIsPro() async throws {
        let mock = MockEntitlement()
        try await mock.purchase(.yearly)
        #expect(mock.isPro)
    }

    @Test("products 返回三个档位")
    func productsReturnThreePlans() async {
        let mock = MockEntitlement()
        let products = await mock.products()
        #expect(products.count == 3)
        #expect(products.contains { $0.plan == .monthly })
        #expect(products.contains { $0.plan == .yearly })
        #expect(products.contains { $0.plan == .lifetime })
    }
}

// MARK: - WordBackup Tests

@Suite("WordBackup")
struct WordBackupTests {

    private func sampleDTO() -> WordDTO {
        WordDTO(
            headword: "Serendipity", lemma: "serendipity", language: "en",
            definition: "n. 意外发现珍宝的运气", definitionEn: nil, phonetic: "ˌserənˈdipiti",
            tags: ["favorite", "hard"], createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            isFavorite: true,
            familiarity: 3, easeFactor: 2.6, interval: 6, repetitions: 3,
            dueAt: Date(timeIntervalSince1970: 1_700_500_000),
            lastReviewedAt: Date(timeIntervalSince1970: 1_700_000_500)
        )
    }

    @Test("WordBackup encode/decode round-trip 数据一致")
    func roundTrip() throws {
        let backup = WordBackup(
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            words: [sampleDTO()]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(WordBackup.self, from: data)

        #expect(decoded.version == WordBackup.currentVersion)
        #expect(decoded.words.count == 1)
        let w = try #require(decoded.words.first)
        #expect(w.headword == "Serendipity")
        #expect(w.lemma == "serendipity")
        #expect(w.definition == "n. 意外发现珍宝的运气")
        #expect(w.phonetic == "ˌserənˈdipiti")
        #expect(w.tags == ["favorite", "hard"])
        #expect(w.isFavorite == true)
        #expect(w.familiarity == 3)
        #expect(w.easeFactor == 2.6)
        #expect(w.interval == 6)
        #expect(w.repetitions == 3)
        #expect(w.dueAt == Date(timeIntervalSince1970: 1_700_500_000))
    }

    @Test("可选字段为 nil 时也能 round-trip")
    func roundTripWithNils() throws {
        let dto = WordDTO(
            headword: "test", lemma: "test", language: "en",
            definition: nil, definitionEn: nil, phonetic: nil,
            tags: [], createdAt: Date(timeIntervalSince1970: 0), isFavorite: false,
            familiarity: 0, easeFactor: 2.5, interval: 0, repetitions: 0,
            dueAt: nil, lastReviewedAt: nil
        )
        let backup = WordBackup(exportedAt: Date(timeIntervalSince1970: 0), words: [dto])

        let data = try JSONEncoder().encode(backup)
        let decoded = try JSONDecoder().decode(WordBackup.self, from: data)

        let w = try #require(decoded.words.first)
        #expect(w.definition == nil)
        #expect(w.dueAt == nil)
        #expect(w.tags.isEmpty)
    }

    @Test("默认 version 为当前版本")
    func defaultVersion() {
        let backup = WordBackup(exportedAt: Date(timeIntervalSince1970: 0), words: [])
        #expect(backup.version == 1)
        #expect(backup.version == WordBackup.currentVersion)
    }
}

// MARK: - StatsCalculator Tests

@Suite("StatsCalculator")
struct StatsCalculatorTests {

    var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    let now = Date(timeIntervalSince1970: 1_700_000_000) // 固定基准

    @Test("熟悉度分布始终返回 6 个桶并正确计数")
    func familiarityDistribution() {
        let buckets = StatsCalculator.familiarityDistribution([0, 0, 3, 5, 5, 5])
        #expect(buckets.count == 6)
        #expect(buckets[0].count == 2)
        #expect(buckets[3].count == 1)
        #expect(buckets[5].count == 3)
        #expect(buckets[1].count == 0)
    }

    @Test("熟悉度越界值被钳制到 0–5")
    func familiarityClamped() {
        let buckets = StatsCalculator.familiarityDistribution([-1, 99, 7])
        #expect(buckets[0].count == 1)   // -1 → 0
        #expect(buckets[5].count == 2)   // 99,7 → 5
    }

    @Test("收录趋势按天分桶，窗口含今天且补零")
    func collectTrend() {
        let today = cal.startOfDay(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let dates = [today, today, yesterday]
        let trend = StatsCalculator.collectTrend(dates: dates, days: 7, now: now, calendar: cal)
        #expect(trend.count == 7)
        #expect(trend.last?.count == 2)        // 今天 2 条
        #expect(trend[trend.count - 2].count == 1) // 昨天 1 条
        #expect(trend.first?.count == 0)       // 7 天前补零
    }

    @Test("复习趋势统计每天总数与答对数")
    func reviewTrend() {
        let today = cal.startOfDay(for: now)
        let entries = [
            (date: today, grade: 4),  // 对
            (date: today, grade: 5),  // 对
            (date: today, grade: 1),  // 错
        ]
        let trend = StatsCalculator.reviewTrend(entries: entries, days: 3, now: now, calendar: cal)
        let todayBucket = trend.last!
        #expect(todayBucket.total == 3)
        #expect(todayBucket.correct == 2)
        #expect(abs((todayBucket.accuracy ?? 0) - 2.0/3.0) < 0.0001)
    }

    @Test("summary 正确分类掌握/学习中/新词与正确率")
    func summary() {
        let s = StatsCalculator.summary(
            familiarities: [0, 0, 2, 4, 5],   // 2新 1学习中 2掌握
            reviewGrades: [5, 4, 1, 3]        // 3对 1错
        )
        #expect(s.totalWords == 5)
        #expect(s.fresh == 2)
        #expect(s.learning == 1)
        #expect(s.mastered == 2)
        #expect(s.totalReviews == 4)
        #expect(abs((s.overallAccuracy ?? 0) - 0.75) < 0.0001)
    }

    @Test("无复习时正确率为 nil")
    func noReviewsAccuracyNil() {
        let s = StatsCalculator.summary(familiarities: [1, 2], reviewGrades: [])
        #expect(s.overallAccuracy == nil)
        #expect(s.totalReviews == 0)
    }
}
