import Foundation
import SwiftData
import WordClipKit

/// 学习会话：管理选词策略、SM-2 评分、进度统计。
///
/// 选词优先级：
///   1. dueAt <= now 的到期词
///   2. familiarity == 0 的新词
///   3. 其余词按 familiarity 升序，各组内随机打散
/// 同一 session 内已出现过的词不重复，所有词过一遍后循环。
@MainActor
final class StudySession: ObservableObject {

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

    struct Stats {
        var total: Int = 0
        var due: Int = 0
        var newWords: Int = 0
    }
    @Published var stats = Stats()

    // MARK: - Private

    private var modelContext: ModelContext?
    private let engine: any ReviewEngine
    private var sessionSeen: Set<PersistentIdentifier> = []
    private var queue: [WordEntry] = []

    init(engine: any ReviewEngine = SM2Engine()) {
        self.engine = engine
    }

    // MARK: - Setup

    func updateContext(_ context: ModelContext) {
        modelContext = context
    }

    // MARK: - Public API

    func refreshStats() {
        let all = fetchAll()
        let now = Date()
        stats = Stats(
            total: all.count,
            due: all.filter { ($0.dueAt ?? .distantPast) <= now && $0.familiarity > 0 }.count,
            newWords: all.filter { $0.familiarity == 0 }.count
        )
    }

    func start() {
        sessionCount = 0
        sessionCorrect = 0
        sessionSeen = []
        queue = buildQueue()
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

    /// 评分：true = 认识(grade 4)，false = 不认识(grade 1)
    func grade(correct: Bool) {
        guard let entry = current, phase == .back else { return }

        let g = correct ? 4 : 1
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

    private func advance() {
        if queue.isEmpty {
            let remaining = fetchAll().filter { !sessionSeen.contains($0.persistentModelID) }
            if remaining.isEmpty {
                // 全部学完，循环
                sessionSeen = []
                queue = buildQueue()
                guard !queue.isEmpty else { phase = .finished; current = nil; return }
            } else {
                queue = sortByPriority(remaining)
            }
        }

        guard !queue.isEmpty else { phase = .finished; current = nil; return }

        let next = queue.removeFirst()
        sessionSeen.insert(next.persistentModelID)
        current = next
        phase = .front
    }

    private func buildQueue() -> [WordEntry] {
        sortByPriority(fetchAll().filter { !sessionSeen.contains($0.persistentModelID) })
    }

    private func sortByPriority(_ words: [WordEntry]) -> [WordEntry] {
        let now = Date()
        let due    = words.filter { ($0.dueAt ?? .distantPast) <= now && $0.familiarity > 0 }.shuffled()
        let newW   = words.filter { $0.familiarity == 0 }.shuffled()
        let others = words.filter { ($0.dueAt ?? .distantPast) > now  && $0.familiarity > 0 }
                         .sorted { $0.familiarity < $1.familiarity }
        return due + newW + others
    }

    private func fetchAll() -> [WordEntry] {
        guard let ctx = modelContext else { return [] }
        let descriptor = FetchDescriptor<WordEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? ctx.fetch(descriptor)) ?? []
    }
}
