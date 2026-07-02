import Testing
import Foundation
import GRDB
@testable import WordClipKit

// MARK: - GRDBDictionaryProvider (inflection / fallback) Tests

@Suite("GRDBDictionary lookup")
struct GRDBDictionaryLookupTests {

    /// 构建一个最小词库：bring（含变形 exchange）、quality（含复数）、configuration。
    private func makeProvider() throws -> (GRDBDictionaryProvider, String) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dicttest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("d.sqlite").path

        let queue = try DatabaseQueue(path: path)
        try queue.write { db in
            try db.execute(sql: """
                CREATE TABLE entries (
                    id INTEGER PRIMARY KEY, word TEXT NOT NULL, lemma TEXT,
                    phonetic TEXT, definition TEXT, definition_en TEXT,
                    pos TEXT, exchange TEXT, freq_rank INTEGER DEFAULT 999999
                );
            """)
            try db.execute(sql: """
                INSERT INTO entries (word, definition, exchange, freq_rank) VALUES
                ('bring', 'vt. 带来, 产生', 'd:brought/p:brought/i:bringing/3:brings', 100),
                ('quality', 'n. 品质, 质量', 's:qualities', 200),
                ('configuration', 'n. 配置', NULL, 300);
            """)
        }
        return (try GRDBDictionaryProvider(dbPath: path), path)
    }

    @Test("精确匹配命中")
    func exact() async throws {
        let (dict, _) = try makeProvider()
        let r = await dict.lookup("quality")
        #expect(r?.definition == "n. 品质, 质量")
    }

    @Test("过去式 brought 经 exchange 还原到 bring")
    func inflectionPast() async throws {
        let (dict, _) = try makeProvider()
        let r = await dict.lookup("brought")
        #expect(r != nil)
        #expect(r?.lemma == "bring")
        #expect(r?.definition?.contains("带来") == true)
        #expect(r?.definition?.hasPrefix("[bring]") == true)
    }

    @Test("复数 qualities 经 exchange 还原到 quality")
    func inflectionPlural() async throws {
        let (dict, _) = try makeProvider()
        let r = await dict.lookup("qualities")
        #expect(r?.lemma == "quality")
        #expect(r?.definition?.contains("品质") == true)
    }

    @Test("前缀 fallback：config → configuration")
    func prefixFallback() async throws {
        let (dict, _) = try makeProvider()
        let r = await dict.lookup("config")
        #expect(r?.definition?.contains("配置") == true)
    }

    @Test("查无此词返回 nil")
    func miss() async throws {
        let (dict, _) = try makeProvider()
        let r = await dict.lookup("zzzznotaword")
        #expect(r == nil)
    }
}

// MARK: - CompositeDictionaryProvider Tests

@Suite("CompositeDictionary")
struct CompositeDictionaryTests {

    /// 内存假词库。
    struct FakeDict: DictionaryProvider {
        let entries: [String: String]   // word -> definition
        func lookup(_ word: String) async -> DictionaryResult? {
            guard let def = entries[word.lowercased()] else { return nil }
            return DictionaryResult(word: word, definition: def)
        }
        func suggest(prefix p: String, limit: Int) async -> [String] {
            let matches = entries.keys.filter { $0.hasPrefix(p.lowercased()) }.sorted()
            return Array(matches.prefix(limit))
        }
    }

    @Test("lookup 返回首个命中（优先级顺序）")
    func lookupPriority() async {
        let a = FakeDict(entries: ["run": "内置：跑"])
        let b = FakeDict(entries: ["run": "自定义：奔跑", "quux": "自定义词"])
        let composite = CompositeDictionaryProvider([a, b])

        let r = await composite.lookup("run")
        #expect(r?.definition == "内置：跑")   // a 优先

        let r2 = await composite.lookup("quux")
        #expect(r2?.definition == "自定义词")   // 仅 b 有
    }

    @Test("lookup 全部未命中返回 nil")
    func lookupMiss() async {
        let composite = CompositeDictionaryProvider([FakeDict(entries: [:])])
        #expect(await composite.lookup("nope") == nil)
    }

    @Test("suggest 合并去重并保持优先级、截断到 limit")
    func suggestMergeDedup() async {
        let a = FakeDict(entries: ["apple": "1", "apply": "2"])
        let b = FakeDict(entries: ["apple": "dup", "apricot": "3"])
        let composite = CompositeDictionaryProvider([a, b])

        let s = await composite.suggest(prefix: "ap", limit: 10)
        #expect(s == ["apple", "apply", "apricot"])   // apple 去重，a 的在前
    }

    @Test("suggest 尊重 limit")
    func suggestLimit() async {
        let a = FakeDict(entries: ["aa": "1", "ab": "2", "ac": "3"])
        let composite = CompositeDictionaryProvider([a])
        let s = await composite.suggest(prefix: "a", limit: 2)
        #expect(s.count == 2)
    }

    @Test("空 providers 安全")
    func empty() async {
        let composite = CompositeDictionaryProvider([])
        #expect(await composite.lookup("x") == nil)
        #expect(await composite.suggest(prefix: "x", limit: 5).isEmpty)
    }
}

// MARK: - DictionaryImporter Tests

@Suite("DictionaryImporter")
struct DictionaryImporterTests {

    private func tmp(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("imp-\(UUID().uuidString)-\(name)")
    }

    @Test("CSV 解析：逗号/表头/音标列")
    func parseCSVBasic() {
        let raw = "word,definition,phonetic\napple,苹果,ˈæpl\nrun,跑\n"
        let rows = DictionaryImporter.parseCSV(raw)
        #expect(rows.count == 2)             // 表头被跳过
        #expect(rows[0] == .init(word: "apple", definition: "苹果", phonetic: "ˈæpl"))
        #expect(rows[1] == .init(word: "run", definition: "跑", phonetic: nil))
    }

    @Test("CSV 解析：制表符分隔 + 引号转义")
    func parseCSVTabAndQuotes() {
        let raw = "hello\t\"你好, 世界\"\n"
        let rows = DictionaryImporter.parseCSV(raw)
        #expect(rows.count == 1)
        #expect(rows[0].word == "hello")
        #expect(rows[0].definition == "你好, 世界")   // 逗号在引号内不拆列
    }

    @Test("CSV 导入后可经 GRDBDictionaryProvider 查询")
    func importCSVQueryable() async throws {
        let src = tmp("d.csv")
        try "banana,香蕉,bəˈnænə\ncherry,樱桃\n".write(to: src, atomically: true, encoding: .utf8)
        let dest = tmp("out.sqlite").path

        let result = try DictionaryImporter.import(from: src, to: dest)
        #expect(result.wordCount == 2)

        let dict = try GRDBDictionaryProvider(dbPath: dest)
        let r = await dict.lookup("banana")
        #expect(r?.definition == "香蕉")
        #expect(r?.phonetic == "bəˈnænə")
        let s = await dict.suggest(prefix: "c", limit: 5)
        #expect(s.contains("cherry"))
    }

    @Test("不支持的扩展名抛错")
    func unsupportedExt() {
        let src = tmp("x.mdx")
        try? "x".write(to: src, atomically: true, encoding: .utf8)
        #expect(throws: DictionaryImporter.ImportError.self) {
            try DictionaryImporter.import(from: src, to: tmp("o.sqlite").path)
        }
    }

    @Test("采用 ECDICT 结构的 SQLite")
    func adoptSQLite() async throws {
        // 造一个含 entries 的源库
        let src = tmp("ecdict.sqlite")
        let q = try DatabaseQueue(path: src.path)
        try await q.write { db in
            try DictionaryImporter.createSchema(db)
            try db.execute(sql: "INSERT INTO entries (word, definition) VALUES ('zephyr', '和风')")
        }
        let dest = tmp("adopted.sqlite").path
        let result = try DictionaryImporter.import(from: src, to: dest)
        #expect(result.wordCount == 1)

        let dict = try GRDBDictionaryProvider(dbPath: dest)
        #expect(await dict.lookup("zephyr")?.definition == "和风")
    }
}

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
        try await mock.purchase(.lifetime)
        #expect(mock.isPro)
    }

    @Test("products 只返回终身买断一档")
    func productsReturnLifetimeOnly() async {
        let mock = MockEntitlement()
        let products = await mock.products()
        #expect(products.count == 1)
        #expect(products.allSatisfy { $0.product == .lifetime })
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

// MARK: - DefinitionFormatter Tests

@Suite("DefinitionFormatter")
struct DefinitionFormatterTests {

    @Test("单行词性前缀被拆分")
    func singlePOS() {
        let lines = DefinitionFormatter.parse("a. 美丽的")
        #expect(lines.count == 1)
        #expect(lines[0].pos == "a.")
        #expect(lines[0].tag == nil)
        #expect(lines[0].text == "美丽的")
    }

    @Test("多行按词性分行")
    func multiLine() {
        let raw = "n. 跑, 赛跑\nvi. 跑, 奔跑\nvt. 使跑"
        let lines = DefinitionFormatter.parse(raw)
        #expect(lines.count == 3)
        #expect(lines.map(\.pos) == ["n.", "vi.", "vt."])
        #expect(lines[0].text == "跑, 赛跑")
    }

    @Test("学科标记被识别并去括号")
    func subjectTag() {
        let lines = DefinitionFormatter.parse("[计] 配置")
        #expect(lines.count == 1)
        #expect(lines[0].pos == nil)
        #expect(lines[0].tag == "计")
        #expect(lines[0].text == "配置")
    }

    @Test("configuration 真实样例：词性行 + 学科行")
    func configurationSample() {
        let raw = "n. 结构, 表面配置, 外形, 配置\n[计] 配置"
        let lines = DefinitionFormatter.parse(raw)
        #expect(lines.count == 2)
        #expect(lines[0].pos == "n.")
        #expect(lines[0].text == "结构, 表面配置, 外形, 配置")
        #expect(lines[1].tag == "计")
        #expect(lines[1].text == "配置")
    }

    @Test("组合词性 vt.&vi. 被拼接")
    func combinedPOS() {
        let lines = DefinitionFormatter.parse("vt.&vi. 改变")
        #expect(lines.count == 1)
        #expect(lines[0].pos == "vt.&vi.")
        #expect(lines[0].text == "改变")
    }

    @Test("无词性无标记的纯文本行原样保留")
    func plainText() {
        let lines = DefinitionFormatter.parse("run的过去式和过去分词")
        #expect(lines.count == 1)
        #expect(lines[0].pos == nil)
        #expect(lines[0].tag == nil)
        #expect(lines[0].text == "run的过去式和过去分词")
    }

    @Test("空行被忽略")
    func emptyLinesIgnored() {
        let lines = DefinitionFormatter.parse("n. 名词\n\n\nv. 动词")
        #expect(lines.count == 2)
    }

    @Test("不认识的缩写不当作词性")
    func unknownAbbrevNotPOS() {
        // "etc." 不在已知词性集合，整行作为正文保留
        let lines = DefinitionFormatter.parse("etc. 等等")
        #expect(lines.count == 1)
        #expect(lines[0].pos == nil)
        #expect(lines[0].text == "etc. 等等")
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
