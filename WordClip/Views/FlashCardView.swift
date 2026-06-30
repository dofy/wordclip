import SwiftUI
import WordClipKit

/// 可翻转的单词卡片。
/// 正面：单词 + 音标；背面：释义。
/// 点击卡片或按空格翻转。
struct FlashCardView: View {
    let entry: WordEntry
    let isFlipped: Bool
    let onFlip: () -> Void

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // 正面
            cardFace {
                VStack(spacing: 12) {
                    Spacer()
                    Text(entry.headword)
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
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
                    FamiliarityBadge(familiarity: entry.familiarity)
                    Spacer()
                    Text(String(localized: "study.tap.to.flip", defaultValue: "点击查看释义"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 16)
                }
            }
            .opacity(rotation < 90 ? 1 : 0)

            // 背面
            cardFace {
                VStack(spacing: 12) {
                    Text(entry.headword)
                        .font(.title2.bold())
                        .foregroundStyle(.secondary)
                    Divider()
                    ScrollView {
                        Text(entry.definition ?? String(localized: "wordlist.nodef", defaultValue: "暂无释义"))
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .textSelection(.enabled)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 20)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
            .opacity(rotation >= 90 ? 1 : 0)
        }
        .frame(maxWidth: 600)
        .aspectRatio(1.55, contentMode: .fit)
        .frame(maxHeight: 400)
        .onTapGesture { flip() }
        .onChange(of: isFlipped) { _, flipped in
            withAnimation(.spring(duration: 0.45)) {
                rotation = flipped ? 180 : 0
            }
        }
        // 空格键翻转
        .onKeyPress(.space) { flip(); return .handled }
        .focusable()
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
