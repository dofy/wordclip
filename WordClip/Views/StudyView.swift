import SwiftUI
import SwiftData
import WordClipKit

/// 随机学习主页面。
/// idle 状态显示统计 + 开始按钮；学习中显示翻转卡片 + 评分按钮。
struct StudyView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var session = StudySession()

    var body: some View {
        Group {
            switch session.phase {
            case .idle:
                idleView
            case .front, .back:
                studyingView
            case .finished:
                finishedView
            }
        }
        .navigationTitle(String(localized: "tab.review", defaultValue: "复习"))
        .onAppear {
            session.updateContext(modelContext)
            session.refreshStats()
        }
        #if os(macOS)
        // 状态栏「开始复习」：切到本页后自动开始一轮
        .onReceive(NotificationCenter.default.publisher(for: .startReviewFromMenuBar)) { _ in
            session.updateContext(modelContext)
            session.refreshStats()
            if session.stats.total > 0 { session.start() }
        }
        #endif
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            HStack(spacing: 12) {
                statCard(value: session.stats.total,
                         label: String(localized: "study.stat.total", defaultValue: "总词数"),
                         color: .blue)
                statCard(value: session.stats.due,
                         label: String(localized: "study.stat.due", defaultValue: "待复习"),
                         color: .orange)
                statCard(value: session.stats.newWords,
                         label: String(localized: "study.stat.new", defaultValue: "新词"),
                         color: .green)
            }
            .padding(.horizontal, 20)

            if session.stats.total == 0 {
                Text(String(localized: "study.empty",
                            defaultValue: "还没有收藏的单词，先去收录一些吧"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Button {
                    session.start()
                } label: {
                    Label(
                        String(localized: "study.start", defaultValue: "开始学习"),
                        systemImage: "play.fill"
                    )
                    .font(.title3.bold())
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                VStack(spacing: 6) {
                    Text(String(localized: "study.principle.hint",
                                defaultValue: "认识 → 下次间隔拉长；不认识 → 打回明天重来（SM-2 间隔重复）"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        NotificationCenter.default.post(name: .showHelp, object: nil)
                    } label: {
                        Text(String(localized: "study.principle.more", defaultValue: "了解更多"))
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }
                .padding(.horizontal, 20)
            }

            Spacer()
        }
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .padding()
    }

    @ViewBuilder
    private func statCard(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Studying

    private var studyingView: some View {
        VStack(spacing: 0) {
            // 顶部：进度 + 停止按钮
            HStack {
                Button {
                    session.stop()
                } label: {
                    Label(String(localized: "study.stop", defaultValue: "停止"),
                          systemImage: "stop.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(session.sessionCount) / \(session.stats.total)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    coverageBar
                        .frame(width: 120, height: 6)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Spacer()

            if let entry = session.current {
                FlashCardView(
                    entry: entry,
                    isFlipped: session.phase == .back,
                    onFlip: { session.flip() }
                )
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }

            Spacer()

            gradeButtons
                .frame(maxWidth: 600)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
        }
        .background(spaceFlipShortcut)
    }

    /// 正面时用空格键翻转。隐藏按钮承载快捷键，避免依赖卡片 focusable（蓝框）。
    @ViewBuilder
    private var spaceFlipShortcut: some View {
        if session.phase == .front {
            Button { session.flip() } label: { EmptyView() }
                .keyboardShortcut(.space, modifiers: [])
                .opacity(0)
                .accessibilityHidden(true)
        }
    }

    private var coverageBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                let ratio = session.stats.total > 0
                    ? Double(session.stats.total - session.stats.newWords) / Double(session.stats.total)
                    : 0.0
                Capsule()
                    .fill(Color.green.opacity(0.7))
                    .frame(width: geo.size.width * ratio)
                    .animation(.spring, value: ratio)
            }
        }
    }

    @ViewBuilder
    private var gradeButtons: some View {
        if session.phase == .back {
            HStack(spacing: 20) {
                Button {
                    session.grade(correct: false)
                } label: {
                    Label(String(localized: "study.grade.wrong", defaultValue: "不认识"),
                          systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .font(.body.bold())
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button {
                    session.grade(correct: true)
                } label: {
                    Label(String(localized: "study.grade.correct", defaultValue: "认识"),
                          systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .font(.body.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }
        } else {
            Text(String(localized: "study.flip.hint", defaultValue: "点击卡片或按空格键翻转"))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(height: 52)
        }
    }

    // MARK: - Finished

    private var finishedView: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text(String(localized: "study.finished.title", defaultValue: "本轮学习完成"))
                    .font(.title2.bold())
                let pct = session.sessionCount > 0
                    ? Int(Double(session.sessionCorrect) / Double(session.sessionCount) * 100)
                    : 0
                Text(String(localized: "study.finished.score",
                            defaultValue: "答对 \(session.sessionCorrect) / \(session.sessionCount)（\(pct)%）"))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button {
                    session.stop()
                } label: {
                    Text(String(localized: "study.finished.back", defaultValue: "返回"))
                        .padding(.horizontal, 24)
                }
                .buttonStyle(.bordered)

                Button {
                    session.start()
                } label: {
                    Text(String(localized: "study.finished.again", defaultValue: "再来一轮"))
                        .padding(.horizontal, 24)
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding()
    }
}
