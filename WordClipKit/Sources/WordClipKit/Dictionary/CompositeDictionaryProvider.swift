import Foundation

/// 多词库叠加：按优先级依次查询多个 `DictionaryProvider`。
/// - lookup：返回首个命中的结果（内置词典优先，其后是用户导入的词库）。
/// - suggest：合并各词库的前缀建议，去重后保持优先级顺序，截断到 limit。
///
/// 顺序即优先级：providers[0] 最优先。
public final class CompositeDictionaryProvider: DictionaryProvider {

    private let providers: [any DictionaryProvider]

    public init(_ providers: [any DictionaryProvider]) {
        self.providers = providers
    }

    public func lookup(_ word: String) async -> DictionaryResult? {
        for provider in providers {
            if let hit = await provider.lookup(word) {
                return hit
            }
        }
        return nil
    }

    public func suggest(prefix: String, limit: Int) async -> [String] {
        var seen = Set<String>()
        var merged: [String] = []
        for provider in providers {
            // 每个子库多取一些，合并去重后再统一截断
            let hits = await provider.suggest(prefix: prefix, limit: limit)
            for word in hits where !seen.contains(word.lowercased()) {
                seen.insert(word.lowercased())
                merged.append(word)
                if merged.count >= limit { return merged }
            }
        }
        return merged
    }
}
