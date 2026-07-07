import Foundation
import SwiftData

/// 移除词包的核心编排(平台无关,可单测):
/// 删组内全部 `WordEntry`(`sources` 走 cascade)、对应 `ReviewLog`(按 wordID 手动清,
/// 因为 ReviewLog 不与 WordEntry 建关系),最后删 `WordGroup` 本身。
/// 移除后该组不再存在,词包在浏览页恢复「未导入」,可重新导入。
public enum WordPackRemover {

    /// - Returns: 删除的词条数量。
    @discardableResult
    public static func remove(group: WordGroup, in context: ModelContext) -> Int {
        let gid = group.id
        let words = (try? context.fetch(
            FetchDescriptor<WordEntry>(predicate: #Predicate { $0.group?.id == gid })
        )) ?? []

        // ReviewLog 按 wordID 存储(无关系),需按词条 id 手动清理,避免孤儿日志污染统计。
        let wordIDs = Set(words.map(\.id))
        let logs = (try? context.fetch(
            FetchDescriptor<ReviewLog>(predicate: #Predicate { wordIDs.contains($0.wordID) })
        )) ?? []
        for log in logs { context.delete(log) }

        for word in words { context.delete(word) }   // sources 关系 cascade 自动清
        context.delete(group)
        try? context.save()
        return words.count
    }
}
