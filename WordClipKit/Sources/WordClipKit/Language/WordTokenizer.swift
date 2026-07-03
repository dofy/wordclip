import Foundation

/// 纯文本分词工具：从一段文本里抽取候选英文单词。
///
/// 与 App 层 `WordCollector.extractWord`（只取首词）职责不同：
/// 这里面向 OCR / 整段文本，返回**多个**候选词，供用户从选词面板里挑选。
/// 纯函数、无平台依赖，便于单元测试。
public enum WordTokenizer {

    /// 从原始文本中抽取候选英文单词。
    ///
    /// 规则：
    /// - 按空白/换行拆分为 token；
    /// - 每个 token 去掉首尾非字母字符（标点、数字等）；
    /// - 只保留由拉丁字母组成的词（允许内部连字符 `-` 与撇号 `'`，如 `well-being` / `it's`）——
    ///   纯 CJK 或含非拉丁字母的 token 被丢弃；
    /// - 长度需 ≥ `minLength`；
    /// - 大小写不敏感去重，保留首次出现顺序（返回去重后的原始形态）。
    ///
    /// - Parameters:
    ///   - raw: 原始文本（可能多行、含标点与中文）。
    ///   - minLength: 最短保留长度，默认 2（滤掉散落的单字母）。
    /// - Returns: 去重且保序的候选词数组。
    public static func extractWords(from raw: String, minLength: Int = 2) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for rawToken in raw.split(whereSeparator: { $0.isWhitespace }) {
            let token = String(rawToken)
            // 去掉首尾非字母字符（标点、数字、引号等）。
            let cleaned = token.trimmingCharacters(in: CharacterSet.letters.inverted)
            guard cleaned.count >= minLength else { continue }
            // 仅拉丁字母词（含内部 - 和 '），滤掉纯 CJK / 混杂非拉丁字母。
            guard cleaned.allSatisfy({ $0.isLatinLetter || $0 == "-" || $0 == "'" }),
                  cleaned.contains(where: { $0.isLatinLetter })
            else { continue }

            let key = cleaned.lowercased()
            if seen.insert(key).inserted {
                result.append(cleaned)
            }
        }

        return result
    }
}

private extension Character {
    /// 是否为基本拉丁字母 a–z / A–Z（排除带音标的拉丁扩展与 CJK）。
    var isLatinLetter: Bool {
        ("a"..."z").contains(self) || ("A"..."Z").contains(self)
    }
}
