import Foundation

/// 词包导入的纯逻辑部分(去重计算),不依赖 SwiftData,便于单测。
/// 落库(找/建 WordGroup、插入 WordEntry)在 App 端 WordPackStore 完成。
public enum WordPackImporter {

    /// 返回 pack 中「本组尚未存在」的词,保持原序;pack 内部重复 lemma 只留首个。
    public static func newWords(in pack: WordPackDTO, existingLemmas: Set<String>) -> [WordPackWordDTO] {
        var seen = existingLemmas
        var result: [WordPackWordDTO] = []
        for word in pack.words {
            let key = word.lemma.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(word)
        }
        return result
    }
}
