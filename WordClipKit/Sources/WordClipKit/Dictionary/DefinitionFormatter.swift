import Foundation

// MARK: - DefinitionLine

/// 一条结构化释义：词性 + 学科标记 + 正文。
/// 由 `DefinitionFormatter` 从词典 definition 原文解析而来，供卡片背面、详情页共用。
public struct DefinitionLine: Equatable, Sendable {
    /// 词性缩写，如 "n." "vt." "vt.&vi."；无则为 nil。
    public let pos: String?
    /// 学科标记，如 "计" "化" "医"（不含方括号）；无则为 nil。
    public let tag: String?
    /// 释义正文（已去除词性与标记前缀）。
    public let text: String

    public init(pos: String?, tag: String?, text: String) {
        self.pos = pos
        self.tag = tag
        self.text = text
    }
}

// MARK: - DefinitionFormatter

/// 把 ECDICT 风格的 definition 原文解析成结构化行。
///
/// 原文示例：
/// ```
/// n. 结构, 表面配置, 外形, 配置
/// [计] 配置
/// ```
/// 解析为两行：`(pos: "n.", tag: nil, text: "结构, 表面配置, 外形, 配置")`、
/// `(pos: nil, tag: "计", text: "配置")`。
public enum DefinitionFormatter {

    /// 按 `\n` 拆行并逐行解析；空行被忽略。
    public static func parse(_ raw: String) -> [DefinitionLine] {
        raw
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parseLine(String($0)) }
    }

    /// 解析单行。开头可能带「学科标记」与「词性」，顺序不定，循环剥离。
    static func parseLine(_ line: String) -> DefinitionLine? {
        var rest = line.trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return nil }

        var pos: String?
        var tag: String?

        var changed = true
        while changed {
            changed = false

            // 学科标记 [计] / [化] …
            if tag == nil, rest.hasPrefix("["), let close = rest.firstIndex(of: "]") {
                let inner = rest[rest.index(after: rest.startIndex)..<close]
                if !inner.isEmpty {
                    tag = String(inner)
                    rest = String(rest[rest.index(after: close)...])
                        .trimmingCharacters(in: .whitespaces)
                    changed = true
                    continue
                }
            }

            // 词性前缀 n. / vt. / vt.&vi. …
            if pos == nil, let hit = leadingPOS(rest) {
                pos = hit.pos
                rest = hit.rest
                changed = true
            }
        }

        return DefinitionLine(pos: pos, tag: tag, text: rest)
    }

    /// 已知词性缩写。组合形式（vt.&vi.）由扫描逻辑拼接。
    private static let knownPOS: Set<String> = [
        "n.", "v.", "vt.", "vi.", "a.", "adj.", "ad.", "adv.",
        "prep.", "conj.", "pron.", "art.", "num.", "int.",
        "aux.", "abbr.", "pl.", "vbl.",
    ]

    /// 从行首识别词性前缀，返回 (规范化词性, 剩余正文)。识别失败返回 nil。
    /// 支持组合：`vt.&vi.`、`vt. & vi.`。
    static func leadingPOS(_ s: String) -> (pos: String, rest: String)? {
        var collected: [String] = []
        var cursor = s

        while true {
            // 跳过开头的 "&" 与空白（连接下一个词性）
            if !collected.isEmpty {
                let trimmed = cursor.drop { $0 == "&" || $0 == " " }
                cursor = String(trimmed)
            }

            guard let token = nextPOSToken(cursor) else { break }
            collected.append(token.pos)
            cursor = token.rest
        }

        guard !collected.isEmpty else { return nil }
        // 词性后必须有正文（避免把整行吞成词性）
        let body = cursor.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return nil }
        // 组合词性用 & 连接：vt. + vi. → "vt.&vi."
        return (collected.joined(separator: "&"), body)
    }

    /// 从行首取一个词性 token（letters + 末尾点），需在已知集合中。
    private static func nextPOSToken(_ s: String) -> (pos: String, rest: String)? {
        var idx = s.startIndex
        var letters = ""
        while idx < s.endIndex, s[idx].isLetter {
            letters.append(s[idx])
            idx = s.index(after: idx)
        }
        guard !letters.isEmpty, idx < s.endIndex, s[idx] == "." else { return nil }
        let token = letters.lowercased() + "."
        guard knownPOS.contains(token) else { return nil }
        let rest = String(s[s.index(after: idx)...])
        return (token, rest)
    }
}
