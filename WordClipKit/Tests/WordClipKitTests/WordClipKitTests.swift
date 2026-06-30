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
