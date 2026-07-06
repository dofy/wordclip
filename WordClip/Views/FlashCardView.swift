import SwiftUI
import WordClipKit

/// 可翻转的单词卡片。
/// 正面：单词 + 音标；背面：释义。
/// - macOS：点击卡片翻转（评分用按钮 / 方向键）。
/// - iOS：单击翻转，左划=不认识、右划=认识（`onGrade`）。
struct FlashCardView: View {
    let entry: WordEntry
    let isFlipped: Bool
    let onFlip: () -> Void
    /// iOS 滑动评分回调：true=认识、false=不认识。macOS 传 nil，不启用滑动。
    var onGrade: ((Bool) -> Void)? = nil

    @State private var rotation: Double = 0
    @State private var dragOffset: CGFloat = 0

    /// 触发评分的水平滑动阈值（pt）。
    private let swipeThreshold: CGFloat = 100

    var body: some View {
        ZStack {
            front
                .opacity(rotation < 90 ? 1 : 0)
            back
                .opacity(rotation >= 90 ? 1 : 0)
        }
        .frame(maxWidth: 600)
        .aspectRatio(1.55, contentMode: .fit)
        .frame(maxHeight: 400)
        .contentShape(Rectangle())
        #if os(iOS)
        .offset(x: dragOffset)
        .rotationEffect(.degrees(Double(dragOffset) / 22))
        .overlay { swipeHint }
        #endif
        .onTapGesture { flip() }
        #if os(iOS)
        .gesture(swipeGesture)
        .onChange(of: entry.id) { _, _ in dragOffset = 0 }
        #endif
        .onChange(of: isFlipped) { _, flipped in
            withAnimation(.spring(duration: 0.45)) {
                rotation = flipped ? 180 : 0
            }
        }
    }

    // MARK: - iOS 滑动手势

    #if os(iOS)
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                // 只跟随水平位移，忽略竖向（保留背面释义滚动）。
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragOffset = value.translation.width
            }
            .onEnded { value in
                if value.translation.width > swipeThreshold {
                    onGrade?(true)          // 右划 = 认识
                    dragOffset = 0
                } else if value.translation.width < -swipeThreshold {
                    onGrade?(false)         // 左划 = 不认识
                    dragOffset = 0
                } else {
                    withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
                }
            }
    }

    /// 拖动时在对应方向淡入「认识 / 不认识」提示。
    @ViewBuilder
    private var swipeHint: some View {
        let progress = min(1, abs(dragOffset) / swipeThreshold)
        ZStack {
            hintBadge(text: String(localized: "study.grade.correct", defaultValue: "认识"),
                      systemImage: "checkmark", color: .green)
                .opacity(dragOffset > 12 ? progress : 0)
            hintBadge(text: String(localized: "study.grade.wrong", defaultValue: "不认识"),
                      systemImage: "xmark", color: .red)
                .opacity(dragOffset < -12 ? progress : 0)
        }
        .allowsHitTesting(false)
    }

    private func hintBadge(text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.title3.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(color, in: Capsule())
    }
    #endif

    // MARK: 正面 — 单词居中

    private var front: some View {
        cardFace {
            VStack(spacing: 14) {
                Spacer(minLength: 0)
                Text(entry.headword)
                    .font(.system(size: 44, weight: .bold, design: .serif))
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                HStack(spacing: 10) {
                    if let phonetic = entry.phonetic, !phonetic.isEmpty {
                        Text("/\(phonetic)/")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Speaker.shared.speak(entry.headword)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    FamiliarityBadge(familiarity: entry.familiarity)
                    Text(String(localized: "study.tap.to.flip", defaultValue: "点击查看释义"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 18)
            }
        }
    }

    // MARK: 背面 — 结构化释义

    private var back: some View {
        cardFace {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text(entry.headword)
                        .font(.title2.bold())
                    if let phonetic = entry.phonetic, !phonetic.isEmpty {
                        Text("/\(phonetic)/")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Speaker.shared.speak(entry.headword)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                Divider()
                ScrollView {
                    StructuredDefinitionView(
                        definition: entry.definition,
                        definitionEn: entry.definitionEn
                    )
                }
            }
            .padding(20)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
    }

    @ViewBuilder
    private func cardFace<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(.background)
            .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
            .overlay(content())
            .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
    }

    private func flip() {
        guard !isFlipped else { return }
        onFlip()
    }
}

/// 熟悉度小标签（0–5 颜色渐进）
struct FamiliarityBadge: View {
    let familiarity: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundStyle(i < familiarity ? levelColor : Color.secondary.opacity(0.25))
            }
        }
    }

    private var levelColor: Color {
        switch familiarity {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green.opacity(0.8)
        default: return .green
        }
    }
}
