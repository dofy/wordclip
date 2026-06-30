import Foundation

// MARK: - 统计数据结构

public struct FamiliarityBucket: Identifiable, Sendable {
    public var level: Int      // 0–5
    public var count: Int
    public var id: Int { level }
    public init(level: Int, count: Int) { self.level = level; self.count = count }
}

public struct DailyCount: Identifiable, Sendable {
    public var date: Date      // 当天 00:00
    public var count: Int
    public var id: Date { date }
    public init(date: Date, count: Int) { self.date = date; self.count = count }
}

public struct DailyReview: Identifiable, Sendable {
    public var date: Date
    public var total: Int      // 当天复习总数
    public var correct: Int    // 当天答对数
    public var id: Date { date }
    /// 正确率 0–1，无复习时为 nil
    public var accuracy: Double? { total > 0 ? Double(correct) / Double(total) : nil }
    public init(date: Date, total: Int, correct: Int) {
        self.date = date; self.total = total; self.correct = correct
    }
}

public struct StatsSummary: Sendable {
    public var totalWords: Int
    public var mastered: Int       // familiarity >= 4
    public var learning: Int       // 1 <= familiarity < 4
    public var fresh: Int          // familiarity == 0
    public var totalReviews: Int
    public var overallAccuracy: Double?   // 全部复习的正确率
    public init(totalWords: Int, mastered: Int, learning: Int, fresh: Int,
                totalReviews: Int, overallAccuracy: Double?) {
        self.totalWords = totalWords; self.mastered = mastered
        self.learning = learning; self.fresh = fresh
        self.totalReviews = totalReviews; self.overallAccuracy = overallAccuracy
    }
}

// MARK: - StatsCalculator

/// 纯函数统计聚合，与 SwiftData 解耦，便于单测。
/// 输入用轻量值类型（familiarity 数组、时间戳数组、(date,grade) 数组），
/// 由调用方从模型映射，避免依赖 @Model。
public enum StatsCalculator {

    /// 熟悉度分布：0–5 各级词数，始终返回 6 个桶（含 0）。
    public static func familiarityDistribution(_ familiarities: [Int]) -> [FamiliarityBucket] {
        var counts = [Int](repeating: 0, count: 6)
        for f in familiarities {
            let level = max(0, min(5, f))
            counts[level] += 1
        }
        return (0...5).map { FamiliarityBucket(level: $0, count: counts[$0]) }
    }

    /// 收录趋势：最近 days 天每天的收录数（含收录为 0 的天，便于折线连续）。
    /// - Parameters:
    ///   - dates: 所有 CollectSource.collectedAt
    ///   - days: 统计天数窗口
    ///   - now: 当前时间（注入便于测试）
    ///   - calendar: 日历（注入）
    public static func collectTrend(
        dates: [Date], days: Int, now: Date, calendar: Calendar = .current
    ) -> [DailyCount] {
        let buckets = dayBuckets(days: days, now: now, calendar: calendar)
        var map = [Date: Int]()
        for d in dates {
            let day = calendar.startOfDay(for: d)
            if buckets.contains(day) { map[day, default: 0] += 1 }
        }
        return buckets.map { DailyCount(date: $0, count: map[$0] ?? 0) }
    }

    /// 复习趋势：最近 days 天每天的复习总数与答对数。
    /// - Parameter entries: (复习时间, grade) 列表，grade >= 3 视为答对。
    public static func reviewTrend(
        entries: [(date: Date, grade: Int)], days: Int, now: Date, calendar: Calendar = .current
    ) -> [DailyReview] {
        let buckets = dayBuckets(days: days, now: now, calendar: calendar)
        var total = [Date: Int]()
        var correct = [Date: Int]()
        for e in entries {
            let day = calendar.startOfDay(for: e.date)
            guard buckets.contains(day) else { continue }
            total[day, default: 0] += 1
            if e.grade >= 3 { correct[day, default: 0] += 1 }
        }
        return buckets.map { DailyReview(date: $0, total: total[$0] ?? 0, correct: correct[$0] ?? 0) }
    }

    /// 汇总卡片数据。
    public static func summary(
        familiarities: [Int], reviewGrades: [Int]
    ) -> StatsSummary {
        let total = familiarities.count
        let mastered = familiarities.filter { $0 >= 4 }.count
        let fresh = familiarities.filter { $0 == 0 }.count
        let learning = total - mastered - fresh
        let reviews = reviewGrades.count
        let correctCount = reviewGrades.filter { $0 >= 3 }.count
        let acc = reviews > 0 ? Double(correctCount) / Double(reviews) : nil
        return StatsSummary(
            totalWords: total, mastered: mastered, learning: learning, fresh: fresh,
            totalReviews: reviews, overallAccuracy: acc
        )
    }

    // MARK: - Private

    /// 生成最近 days 天的 00:00 时间点数组（升序，含今天）。
    private static func dayBuckets(days: Int, now: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        return (0..<max(1, days)).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }
}
