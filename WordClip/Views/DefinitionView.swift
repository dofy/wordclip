import SwiftUI
import WordClipKit

/// 词典查询结果的详情预览（搜索结果里点词典项弹出）。
/// 展示单词 + 音标 + 结构化释义 + 朗读，底部「收录到生词本」。
struct DictionaryPreviewView: View {
    let result: DictionaryResult
    /// 收录动作（收录后由调用方关闭 sheet）。
    let onCollect: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isCollecting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text(result.word).font(.largeTitle.bold())
                if let ph = result.phonetic, !ph.isEmpty {
                    Text("/\(ph)/").font(.title3).foregroundStyle(.secondary)
                }
                Button {
                    Speaker.shared.speak(result.word)
                } label: {
                    Image(systemName: "speaker.wave.2.fill").font(.title3).foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .focusable(false)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }

            Divider()

            ScrollView {
                StructuredDefinitionView(
                    definition: result.definition,
                    definitionEn: result.definitionEn
                )
            }

            Divider()
            Button {
                Task {
                    isCollecting = true
                    await onCollect()
                    isCollecting = false
                }
            } label: {
                if isCollecting {
                    ProgressView().controlSize(.small)
                } else {
                    Label(String(localized: "lookup.collect", defaultValue: "收录到生词本"),
                          systemImage: "plus.circle.fill")
                        .font(.body.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCollecting)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(20)
        #if os(macOS)
        .frame(width: 440, height: 400)
        #else
        .presentationDetents([.medium, .large])
        #endif
    }
}

/// 结构化释义展示：词性彩色 badge + 学科标记 + 中英文分区。
/// 卡片背面与详情页共用（解析逻辑见 `DefinitionFormatter`）。
struct StructuredDefinitionView: View {
    let definition: String?
    let definitionEn: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            zhSection
            enSection
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 中文释义

    @ViewBuilder
    private var zhSection: some View {
        if let zh = definition, !zh.isEmpty {
            let lines = DefinitionFormatter.parse(zh)
            if lines.isEmpty {
                Text(zh).font(.body).textSelection(.enabled)
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    DefinitionRow(line: line)
                }
            }
        } else {
            Text(String(localized: "wordlist.nodef", defaultValue: "暂无释义"))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: 英英释义

    @ViewBuilder
    private var enSection: some View {
        if let en = definitionEn, !en.isEmpty {
            Divider().padding(.vertical, 2)
            Label(String(localized: "definition.english", defaultValue: "英英释义"),
                  systemImage: "character.book.closed")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
            Text(en)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 单行结构化释义：[词性] [学科] 正文。
private struct DefinitionRow: View {
    let line: DefinitionLine

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let pos = line.pos {
                Text(pos)
                    .font(.caption.bold())
                    .foregroundStyle(POSStyle.color(for: pos))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(POSStyle.color(for: pos).opacity(0.14),
                                in: Capsule())
            }
            if let tag = line.tag {
                Text(tag)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 4))
            }
            Text(line.text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 词性 → 颜色映射，让背面释义一眼区分词性。
enum POSStyle {
    static func color(for pos: String) -> Color {
        let key = pos
            .split(separator: "&").first.map(String.init)?
            .replacingOccurrences(of: ".", with: "")
            .lowercased() ?? ""
        switch key {
        case "n", "pl":                              return .blue
        case "v", "vt", "vi", "vbl", "aux":          return .green
        case "a", "adj":                             return .orange
        case "ad", "adv":                            return .purple
        case "prep", "conj", "pron", "art", "int", "num", "abbr":
            return .pink
        default:                                     return .gray
        }
    }
}
