import SwiftUI
import WordClipKit

/// 结构化释义展示：词性彩色 badge + 学科标记 + 中英文分区。
/// 卡片背面与详情页共用（解析逻辑见 `DefinitionFormatter`）。
///
/// 两份释义（中文 / 英英）哪份当主释义，取决于界面语言：中文界面先中文释义，
/// 其他语言先英英释义，另一份降级成带标题的次级分区。词库没有繁体释义列，
/// 所以繁体界面走中文分支、显示简体释义（详见 docs/ARCHITECTURE.md §3.7）。
struct StructuredDefinitionView: View {
    let definition: String?
    let definitionEn: String?

    /// 界面语言是中文（简体或繁体）时优先展示中文释义。
    private var prefersChineseGloss: Bool {
        Locale.current.language.languageCode?.identifier == "zh"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if prefersChineseGloss {
                zhSection(isPrimary: true)
                enSection(isPrimary: false)
            } else {
                enSection(isPrimary: true)
                zhSection(isPrimary: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 中文释义

    @ViewBuilder
    private func zhSection(isPrimary: Bool) -> some View {
        if let zh = definition, !zh.isEmpty {
            if !isPrimary {
                sectionHeader(String(localized: "definition.chinese", defaultValue: "Chinese"))
            }
            let lines = DefinitionFormatter.parse(zh)
            if lines.isEmpty {
                Text(zh)
                    .font(isPrimary ? .body : .callout)
                    .foregroundStyle(isPrimary ? .primary : .secondary)
                    .textSelection(.enabled)
            } else {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    DefinitionRow(line: line)
                }
            }
        } else if isPrimary {
            emptyState
        }
    }

    // MARK: 英英释义

    @ViewBuilder
    private func enSection(isPrimary: Bool) -> some View {
        if let en = definitionEn, !en.isEmpty {
            if !isPrimary {
                sectionHeader(String(localized: "definition.english", defaultValue: "English"))
            }
            Text(en)
                .font(isPrimary ? .body : .callout)
                .foregroundStyle(isPrimary ? .primary : .secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if isPrimary {
            emptyState
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Divider().padding(.vertical, 2)
        Label(title, systemImage: "character.book.closed")
            .font(.caption.bold())
            .foregroundStyle(.tertiary)
    }

    private var emptyState: some View {
        Text(String(localized: "wordlist.nodef", defaultValue: "No definition yet"))
            .foregroundStyle(.secondary)
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
