import Foundation
import SwiftData
import WordClipKit

/// 学习会话：每轮固定数量，兼顾「学习」（新词）与「复习」（到期词），学完一轮自动结束。
///
/// 一轮选词（共 roundSize 个）：
///   1. 到期复习词（dueAt <= now 且 familiarity > 0）优先入选
///   2. 剩余名额用新词（familiarity == 0）填满
///   3. 仍不足则用未到期的老词按 familiarity 升序补齐
/// 入选后把「复习词」与「新词」交错排列，避免前半全是复习、后半全是新词。
/// 词量不足 roundSize 时，本轮就学实际数量。队列走完即结束（不再循环）。
@MainActor
final class StudySession: ObservableObject {

    /// 每轮默认词数；设置页可改（UserDefaults 键 study.roundSize）。
    static let defaultRoundSize = 20

    // MARK: - Phase

    enum Phase: Equatable {
        case idle
        case front
        case back
        case finished
    }

    // MARK: - Published

    @Published var phase: Phase = .idle
    @Published var current: WordEntry?
    @Published var sessionCount: Int = 0
    @Published var sessionCorrect: Int = 0
    /// 本轮实际词数（可能小于 roundSize，若词量不足）。
    @Published var roundTotal: Int = 0

    struct Stats {
        var total: Int = 0
        var due: Int = 0
        var newWords: Int = 0
    }
    @Published var stats = Stats()

    /// 当前学习的分组；nil = 全部分组混学。持久化到 UserDefaults。
    @Published var selectedGroupID: UUID?

    private static let selectedGroupKey = "study.selectedGroup"

    // MARK: - Private

    private var modelContext: ModelContext?
    private let engine: any ReviewEngine
    private var queue: [WordEntry] = []

    /// 每轮词数：读设置，回退到默认值。
    private var roundSize: Int {
        let v = UserDefaults.standard.integer(forKey: "study.roundSize")
        return v > 0 ? v : Self.defaultRoundSize
    }

    init(engine: any ReviewEngine = SM2Engine()) {
        self.engine = engine
        if let s = UserDefaults.standard.string(forKey: Self.selectedGroupKey),
           let id = UUID(uuidString: s) {
            selectedGroupID = id
        }
    }

    // MARK: - Setup

    func updateContext(_ context: ModelContext) {
        modelContext = context
    }

    // MARK: - Public API

    /// 切换分组并持久化；调用后应 refreshStats()。
    func setGroup(_ id: UUID?) {
        selectedGroupID = id
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: Self.selectedGroupKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.selectedGroupKey)
        }
        refreshStats()
    }

    func refreshStats() {
        let all = fetchAll()
        let now = Date()
        stats = Stats(
            total: all.count,
            due: all.filter { $0.isDue(asOf: now) }.count,
            newWords: all.filter { $0.isNew }.count
        )
    }

    func start() {
        sessionCount = 0
        sessionCorrect = 0
        queue = buildRound()
        roundTotal = queue.count
        advance()
    }

    func stop() {
        phase = .idle
        current = nil
        refreshStats()
    }

    func flip() {
        guard phase == .front else { return }
        phase = .back
    }

    /// 评分：认识 / 不认识。
    /// - 翻面「前」就认识（没看释义）→ grade 5，记得最牢，间隔拉最长
    /// - 翻面「后」才确认认识（看过释义）→ grade 4，正常间隔
    /// - 不认识 → grade 1
    /// 正面（未翻）或背面均可评分——不认识时通常想直接翻面看释义，认识则可不翻直接过。
    func grade(correct: Bool) {
        guard let entry = current, phase == .front || phase == .back else { return }

        let g: Int
        if correct {
            g = (phase == .front) ? 5 : 4
        } else {
            g = 1
        }
        let state = ReviewState(
            familiarity: entry.familiarity,
            easeFactor: entry.easeFactor,
            interval: entry.interval,
            repetitions: entry.repetitions
        )
        let (next, dueAt) = engine.schedule(state, grade: g, now: Date())

        entry.familiarity    = next.familiarity
        entry.easeFactor     = next.easeFactor
        entry.interval       = next.interval
        entry.repetitions    = next.repetitions
        entry.dueAt          = dueAt
        entry.lastReviewedAt = Date()

        // 记录复习历史，供统计图表使用
        let log = ReviewLog(wordID: entry.id, grade: g, mode: .multipleChoice)
        modelContext?.insert(log)

        try? modelContext?.save()

        sessionCount  += 1
        if correct { sessionCorrect += 1 }

        // 刷新 stats 以便覆盖率进度条实时更新
        refreshStats()
        advance()
    }

    // MARK: - Private

    /// 取下一张卡；队列空即本轮结束（不再循环）。
    private func advance() {
        guard !queue.isEmpty else { phase = .finished; current = nil; return }
        current = queue.removeFirst()
        phase = .front
    }

    /// 构建一轮（至多 roundSize 个）：复习优先、新词填充、老词兜底，再把复习与新词交错。
    private func buildRound() -> [WordEntry] {
        let all = fetchAll()
        let now = Date()

        let due    = all.filter { $0.isDue(asOf: now) }.shuffled()
        let newW   = all.filter { $0.isNew }.shuffled()
        // 已复习过但未到期的老词（兜底填充，最接近到期者优先）
        let others = all.filter { !$0.isNew && !$0.isDue(asOf: now) }
                        .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }

        let cap = roundSize
        // 到期复习词全部优先入选（至多占满本轮）
        let pickedDue = Array(due.prefix(cap))
        // 剩余名额用新词填满
        let remainAfterDue = cap - pickedDue.count
        let pickedNew = Array(newW.prefix(max(0, remainAfterDue)))
        // 仍不足则用未到期老词（最接近到期者优先）兜底
        let remainAfterNew = cap - pickedDue.count - pickedNew.count
        let pickedOthers = Array(others.prefix(max(0, remainAfterNew)))

        return interleave(review: pickedDue + pickedOthers, fresh: pickedNew)
    }

    /// 把「复习词」与「新词」按比例交错，避免前半全复习、后半全新词。
    private func interleave(review: [WordEntry], fresh: [WordEntry]) -> [WordEntry] {
        guard !review.isEmpty else { return fresh }
        guard !fresh.isEmpty else { return review }

        var result: [WordEntry] = []
        result.reserveCapacity(review.count + fresh.count)
        let total = review.count + fresh.count
        var ri = 0, fi = 0
        // 用分数累加决定每一步取复习还是新词，两者按各自占比均匀铺开。
        for step in 0..<total {
            let reviewShare = Double(review.count) / Double(total)
            let wantReview = Double(ri) < reviewShare * Double(step + 1)
            if wantReview && ri < review.count {
                result.append(review[ri]); ri += 1
            } else if fi < fresh.count {
                result.append(fresh[fi]); fi += 1
            } else if ri < review.count {
                result.append(review[ri]); ri += 1
            }
        }
        return result
    }

    private func fetchAll() -> [WordEntry] {
        guard let ctx = modelContext else { return [] }
        var descriptor = FetchDescriptor<WordEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        if let gid = selectedGroupID {
            descriptor.predicate = #Predicate { $0.group?.id == gid }
        }
        return (try? ctx.fetch(descriptor)) ?? []
    }
}
