import SwiftUI
import SwiftData
import Charts
import WordClipKit

// 图表坐标轴标签。Swift Charts 的 `.value(_:_:)` 有 LocalizedStringKey 重载，
// 直接写字面量会被当成本地化 key 抽进目录；这里先取好译文再传 String 重载。
private let statsAxisLevel = String(localized: "stats.axis.level", defaultValue: "Level")
private let statsAxisCount = String(localized: "stats.axis.count", defaultValue: "Count")
private let statsAxisDate = String(localized: "stats.axis.date", defaultValue: "Date")
private let statsAxisAccuracy = String(localized: "stats.axis.accuracy", defaultValue: "Accuracy")

/// 统计页：收录趋势、熟悉度分布、复习认识率。可按分组过滤(与复习页一致)。
struct StatsView: View {
    @Query private var words: [WordEntry]
    @Query(sort: \ReviewLog.date) private var logs: [ReviewLog]

    /// 当前统计的分组;nil = 全部。与复习页的 GroupPicker 同一交互,但各自独立选择。
    @State private var selectedGroupID: UUID?

    private let trendDays = 30

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupPicker(selection: $selectedGroupID)
                content
            }
            .padding(20)
        }
        .navigationTitle(String(localized: "tab.stats", defaultValue: "Stats"))
    }

    @ViewBuilder
    private var content: some View {
        if filteredWords.isEmpty {
            ContentUnavailableView(
                String(localized: "stats.empty.title", defaultValue: "No Stats Yet"),
                systemImage: "chart.xyaxis.line",
                description: Text(String(localized: "stats.empty.desc",
                    defaultValue: "Collect and review words to see your learning stats here"))
            )
            .padding(.top, 40)
        } else {
            VStack(alignment: .leading, spacing: 28) {
                summarySection
                familiaritySection
                collectTrendSection
                if summary.totalReviews > 0 {
                    reviewAccuracySection
                }
            }
        }
    }

    // MARK: - 数据(按当前分组过滤)

    /// 当前分组的词条(nil = 全部)。
    private var filteredWords: [WordEntry] {
        guard let gid = selectedGroupID else { return words }
        return words.filter { $0.group?.id == gid }
    }
    /// 当前分组词条对应的复习日志(ReviewLog 按 wordID 关联,借词条 id 集合过滤)。
    private var filteredLogs: [ReviewLog] {
        guard selectedGroupID != nil else { return logs }
        let ids = Set(filteredWords.map(\.id))
        return logs.filter { ids.contains($0.wordID) }
    }

    private var familiarities: [Int] { filteredWords.map(\.familiarity) }
    private var reviewGrades: [Int] { filteredLogs.map(\.grade) }

    private var summary: StatsSummary {
        StatsCalculator.summary(familiarities: familiarities, reviewGrades: reviewGrades)
    }
    private var distribution: [FamiliarityBucket] {
        StatsCalculator.familiarityDistribution(familiarities)
    }
    private var collectTrend: [DailyCount] {
        StatsCalculator.collectTrend(
            dates: filteredWords.flatMap { $0.sources.map(\.collectedAt) },
            days: trendDays, now: Date()
        )
    }
    private var reviewTrend: [DailyReview] {
        StatsCalculator.reviewTrend(
            entries: filteredLogs.map { (date: $0.date, grade: $0.grade) },
            days: trendDays, now: Date()
        )
    }

    // MARK: - Summary 卡片

    private var summarySection: some View {
        HStack(spacing: 12) {
            summaryCard(value: "\(summary.totalWords)",
                        label: String(localized: "stats.total", defaultValue: "Total"), color: .blue)
            summaryCard(value: "\(summary.mastered)",
                        label: String(localized: "stats.mastered", defaultValue: "Mastered"), color: .green)
            summaryCard(value: "\(summary.learning)",
                        label: String(localized: "stats.learning", defaultValue: "Learning"), color: .orange)
            if let acc = summary.overallAccuracy {
                summaryCard(value: "\(Int(acc * 100))%",
                            label: String(localized: "stats.accuracy", defaultValue: "Recall"), color: .purple)
            }
        }
    }

    private func summaryCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 熟悉度分布

    private var familiaritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(String(localized: "stats.familiarity.title", defaultValue: "Familiarity Distribution"))
            Chart(distribution) { bucket in
                BarMark(
                    x: .value(statsAxisLevel, "L\(bucket.level)"),
                    y: .value(statsAxisCount, bucket.count)
                )
                .foregroundStyle(levelColor(bucket.level))
                .annotation(position: .top) {
                    if bucket.count > 0 {
                        Text(verbatim: "\(bucket.count)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 180)
        }
    }

    // MARK: - 收录趋势

    private var collectTrendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(String(localized: "stats.collect.title", defaultValue: "Last 30 Days Collected"))
            Chart(collectTrend) { day in
                AreaMark(
                    x: .value(statsAxisDate, day.date),
                    y: .value(statsAxisCount, day.count)
                )
                .foregroundStyle(.blue.opacity(0.2))
                LineMark(
                    x: .value(statsAxisDate, day.date),
                    y: .value(statsAxisCount, day.count)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 180)
        }
    }

    // MARK: - 复习认识率

    private var reviewAccuracySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(String(localized: "stats.review.title", defaultValue: "Review Recall"))
            Chart(reviewTrend.filter { $0.total > 0 }) { day in
                LineMark(
                    x: .value(statsAxisDate, day.date),
                    y: .value(statsAxisAccuracy, (day.accuracy ?? 0) * 100)
                )
                .foregroundStyle(.purple)
                .symbol(.circle)
                PointMark(
                    x: .value(statsAxisDate, day.date),
                    y: .value(statsAxisAccuracy, (day.accuracy ?? 0) * 100)
                )
                .foregroundStyle(.purple)
            }
            .chartYScale(domain: 0...100)
            .frame(height: 180)
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.headline)
    }

    private func levelColor(_ level: Int) -> Color {
        switch level {
        case 0: return .secondary
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green.opacity(0.7)
        default: return .green
        }
    }
}
