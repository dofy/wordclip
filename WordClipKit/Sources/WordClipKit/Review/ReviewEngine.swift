import Foundation

// MARK: - ReviewState

/// 单个词条的复习状态快照（值类型，与 SwiftData 模型分离，便于测试）。
public struct ReviewState: Sendable, Equatable {
    public var familiarity: Int     // 0–5
    public var easeFactor: Double   // SM-2 EF
    public var interval: Int        // 天
    public var repetitions: Int

    public static let initial = ReviewState(
        familiarity: 0,
        easeFactor: 2.5,
        interval: 0,
        repetitions: 0
    )

    public init(familiarity: Int, easeFactor: Double, interval: Int, repetitions: Int) {
        self.familiarity = familiarity
        self.easeFactor = easeFactor
        self.interval = interval
        self.repetitions = repetitions
    }
}

// MARK: - ReviewEngine

/// 复习算法协议。起步用 SM-2，未来可换 FSRS，接口不变。
public protocol ReviewEngine: Sendable {
    /// 根据当前状态和本次评分，计算下一个复习状态。
    /// - Parameters:
    ///   - state: 当前状态
    ///   - grade: 0–5（0=完全不会, 3=勉强过关, 5=完全掌握）
    ///   - now: 当前时间（注入便于测试）
    /// - Returns: 更新后的状态 + 下次复习日期
    func schedule(_ state: ReviewState, grade: Int, now: Date) -> (ReviewState, Date)
}

// MARK: - SM2Engine

/// 标准 SuperMemo SM-2 算法实现。
public struct SM2Engine: ReviewEngine {

    public init() {}

    public func schedule(_ state: ReviewState, grade: Int, now: Date) -> (ReviewState, Date) {
        let g = max(0, min(5, grade))
        var s = state

        if g < 3 {
            // 答错：重置重复次数，间隔回到 1 天
            s.repetitions = 0
            s.interval = 1
        } else {
            // 答对
            switch s.repetitions {
            case 0:  s.interval = 1
            case 1:  s.interval = 6
            default: s.interval = max(1, Int((Double(s.interval) * s.easeFactor).rounded()))
            }
            s.repetitions += 1
        }

        // 更新 EF（最小 1.3）
        let efDelta = 0.1 - Double(5 - g) * (0.08 + Double(5 - g) * 0.02)
        s.easeFactor = max(1.3, s.easeFactor + efDelta)

        // 熟悉度：连续答对次数映射到 0–5 级
        s.familiarity = min(5, s.repetitions)

        let dueAt = Calendar.current.date(
            byAdding: .day, value: s.interval, to: now
        ) ?? now

        return (s, dueAt)
    }
}
