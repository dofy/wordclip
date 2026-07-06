import SwiftUI
import SwiftData
import Charts
import WordClipKit

/// 统计页：收录趋势、熟悉度分布、复习认识率。
struct StatsView: View {
    @Query private var words: [WordEntry]
    @Query(sort: \ReviewLog.date) private var logs: [ReviewLog]

    private let trendDays = 30

    var body: some View {
        ScrollView {
            if words.isEmpty {
                ContentUnavailableView(
                    String(localized: "stats.empty.title", defaultValue: "还没有统计数据"),
                    systemImage: "chart.xyaxis.line",
                    description: Text(String(localized: "stats.empty.desc",
                        defaultValue: "收录单词并复习后，这里会显示你的学习统计"))
                )
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 28) {
                    summarySection
                    familiaritySection
                    collectTrendSection
                    if summary.totalReviews > 0 {
                        reviewAccuracySection
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(String(localized: "tab.stats", defaultValue: "统计"))
    }

    // MARK: - 数据

    private var familiarities: [Int] { words.map(\.familiarity) }
    private var reviewGrades: [Int] { logs.map(\.grade) }

    private var summary: StatsSummary {
        StatsCalculator.summary(familiarities: familiarities, reviewGrades: reviewGrades)
    }
    private var distribution: [FamiliarityBucket] {
        StatsCalculator.familiarityDistribution(familiarities)
    }
    private var collectTrend: [DailyCount] {
        StatsCalculator.collectTrend(
            dates: words.flatMap { $0.sources.map(\.collectedAt) },
            days: trendDays, now: Date()
        )
    }
    private var reviewTrend: [DailyReview] {
        StatsCalculator.reviewTrend(
            entries: logs.map { (date: $0.date, grade: $0.grade) },
            days: trendDays, now: Date()
        )
    }

    // MARK: - Summary 卡片

    private var summarySection: some View {
        HStack(spacing: 12) {
            summaryCard(value: "\(summary.totalWords)",
                        label: String(localized: "stats.total", defaultValue: "总词数"), color: .blue)
            summaryCard(value: "\(summary.mastered)",
                        label: String(localized: "stats.mastered", defaultValue: "已掌握"), color: .green)
            summaryCard(value: "\(summary.learning)",
                        label: String(localized: "stats.learning", defaultValue: "学习中"), color: .orange)
            if let acc = summary.overallAccuracy {
                summaryCard(value: "\(Int(acc * 100))%",
                            label: String(localized: "stats.accuracy", defaultValue: "认识率"), color: .purple)
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
            sectionTitle(String(localized: "stats.familiarity.title", defaultValue: "熟悉度分布"))
            Chart(distribution) { bucket in
                BarMark(
                    x: .value("Level", "L\(bucket.level)"),
                    y: .value("Count", bucket.count)
                )
                .foregroundStyle(levelColor(bucket.level))
                .annotation(position: .top) {
                    if bucket.count > 0 {
                        Text("\(bucket.count)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 180)
        }
    }

    // MARK: - 收录趋势

    private var collectTrendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(String(localized: "stats.collect.title", defaultValue: "近 30 天收录"))
            Chart(collectTrend) { day in
                AreaMark(
                    x: .value("Date", day.date),
                    y: .value("Count", day.count)
                )
                .foregroundStyle(.blue.opacity(0.2))
                LineMark(
                    x: .value("Date", day.date),
                    y: .value("Count", day.count)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 180)
        }
    }

    // MARK: - 复习认识率

    private var reviewAccuracySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(String(localized: "stats.review.title", defaultValue: "复习认识率"))
            Chart(reviewTrend.filter { $0.total > 0 }) { day in
                LineMark(
                    x: .value("Date", day.date),
                    y: .value("Accuracy", (day.accuracy ?? 0) * 100)
                )
                .foregroundStyle(.purple)
                .symbol(.circle)
                PointMark(
                    x: .value("Date", day.date),
                    y: .value("Accuracy", (day.accuracy ?? 0) * 100)
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
