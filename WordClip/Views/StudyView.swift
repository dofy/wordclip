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
        .navigationTitle(String(localized: "tab.review", defaultValue: "Review"))
        // 长驻词包入口:两端均可从复习页工具栏打开词包浏览。
        .toolbar {
            ToolbarItem {
                Button {
                    NotificationCenter.default.post(name: .showWordPacks, object: nil)
                } label: {
                    Label(String(localized: "menu.wordpacks", defaultValue: "Word Packs…"),
                          systemImage: "square.stack.3d.up")
                }
            }
        }
        .onAppear {
            session.updateContext(modelContext)
            session.refreshStats()
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            GroupPicker(selection: Binding(
                get: { session.selectedGroupID },
                set: { session.setGroup($0) }
            ))
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                statCard(value: session.stats.total,
                         label: String(localized: "study.stat.total", defaultValue: "Total"),
                         color: .blue)
                statCard(value: session.stats.due,
                         label: String(localized: "study.stat.due", defaultValue: "Due"),
                         color: .orange)
                statCard(value: session.stats.newWords,
                         label: String(localized: "study.stat.new", defaultValue: "New"),
                         color: .green)
            }
            .padding(.horizontal, 20)

            if session.stats.total == 0 {
                Text(String(localized: "study.empty",
                            defaultValue: "No saved words yet — go collect a few first"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Button {
                    session.start()
                } label: {
                    Label(
                        String(localized: "study.start", defaultValue: "Start studying"),
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
                                defaultValue: "Know it → next interval grows; Don’t → back to tomorrow (SM-2 spaced repetition)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        NotificationCenter.default.post(name: .showHelp, object: nil)
                    } label: {
                        Text(String(localized: "study.principle.more", defaultValue: "Learn more"))
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
            Text(verbatim: "\(value)")
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
                    Label(String(localized: "study.stop", defaultValue: "Stop"),
                          systemImage: "stop.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(verbatim: "\(session.sessionCount) / \(session.roundTotal)")
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
                    onFlip: { session.flip() },
                    onGrade: { correct in session.grade(correct: correct) }
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
                // 本轮进度：已评分数 / 本轮总数
                let ratio = session.roundTotal > 0
                    ? Double(session.sessionCount) / Double(session.roundTotal)
                    : 0.0
                Capsule()
                    .fill(Color.green.opacity(0.7))
                    .frame(width: geo.size.width * ratio)
                    .animation(.spring, value: ratio)
            }
        }
    }

    /// 认识 / 不认识始终可用（正面未翻也能评分）；正面额外提示可翻面看释义。
    @ViewBuilder
    private var gradeButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                Button {
                    session.grade(correct: false)
                } label: {
                    Label(String(localized: "study.grade.wrong", defaultValue: "Don’t know"),
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
                    Label(String(localized: "study.grade.correct", defaultValue: "Know it"),
                          systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .font(.body.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }

            // 正面时提示可翻面（不强制）；背面留白保持布局稳定。
            Text(session.phase == .front
                 ? String(localized: "study.flip.hint", defaultValue: "Tap the card or press Space to see the definition")
                 : " ")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(height: 16)
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
                Text(String(localized: "study.finished.title", defaultValue: "Round complete"))
                    .font(.title2.bold())
                let pct = session.sessionCount > 0
                    ? Int(Double(session.sessionCorrect) / Double(session.sessionCount) * 100)
                    : 0
                Text(String(localized: "study.finished.score",
                            defaultValue: "Knew \(session.sessionCorrect) of \(session.sessionCount) (\(pct)%)"))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Button {
                    session.stop()
                } label: {
                    Text(String(localized: "study.finished.back", defaultValue: "Back"))
                        .padding(.horizontal, 24)
                }
                .buttonStyle(.bordered)

                Button {
                    session.start()
                } label: {
                    Text(String(localized: "study.finished.again", defaultValue: "Another round"))
                        .padding(.horizontal, 24)
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding()
    }
}
