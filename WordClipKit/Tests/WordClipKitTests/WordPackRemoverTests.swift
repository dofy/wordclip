import Testing
import Foundation
import SwiftData
@testable import WordClipKit

/// 移除词包的核心编排:删组内词条 + 对应 ReviewLog(按 wordID) + 分组本身。
/// 用内存 SwiftData 容器真实验证删除语义。
@Suite("WordPackRemover")
@MainActor
struct WordPackRemoverTests {

    /// 建一个内存容器,含全部模型。
    private func makeContext() throws -> ModelContext {
        let schema = Schema([WordEntry.self, CollectSource.self, ReviewLog.self, WordGroup.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        return ModelContext(container)
    }

    /// 在指定组插入一个词,并给它记一条 ReviewLog。返回词条。
    @discardableResult
    private func insertWord(_ lemma: String, group: WordGroup, in ctx: ModelContext, withLog: Bool = true) -> WordEntry {
        let w = WordEntry(headword: lemma, lemma: lemma)
        w.group = group
        ctx.insert(w)
        if withLog {
            ctx.insert(ReviewLog(wordID: w.id, grade: 3, mode: .multipleChoice))
        }
        return w
    }

    @Test("移除词包:删组内全部词 + 分组本身 + 对应 ReviewLog")
    func removesWordsGroupAndLogs() throws {
        let ctx = try makeContext()
        let pack = WordGroup(name: "旅游娱乐", kind: WordGroup.kindPack, packSlug: "travel")
        ctx.insert(pack)
        insertWord("itinerary", group: pack, in: ctx)
        insertWord("visa", group: pack, in: ctx)
        try ctx.save()

        let removed = WordPackRemover.remove(group: pack, in: ctx)

        #expect(removed == 2)
        let words = try ctx.fetch(FetchDescriptor<WordEntry>())
        #expect(words.isEmpty)
        let groups = try ctx.fetch(FetchDescriptor<WordGroup>())
        #expect(groups.isEmpty)
        let logs = try ctx.fetch(FetchDescriptor<ReviewLog>())
        #expect(logs.isEmpty)
    }

    @Test("不影响其他分组的词与日志")
    func leavesOtherGroupsIntact() throws {
        let ctx = try makeContext()
        let pack = WordGroup(name: "旅游娱乐", kind: WordGroup.kindPack, packSlug: "travel")
        let manual = WordGroup(name: WordGroup.manualGroupName, kind: WordGroup.kindManual)
        ctx.insert(pack)
        ctx.insert(manual)
        insertWord("itinerary", group: pack, in: ctx)
        let kept = insertWord("serendipity", group: manual, in: ctx)
        try ctx.save()

        let removed = WordPackRemover.remove(group: pack, in: ctx)

        #expect(removed == 1)
        let words = try ctx.fetch(FetchDescriptor<WordEntry>())
        #expect(words.map(\.lemma) == ["serendipity"])
        let groups = try ctx.fetch(FetchDescriptor<WordGroup>())
        #expect(groups.map(\.name) == [WordGroup.manualGroupName])
        // 手动组那条词的日志仍在
        let keptID = kept.id
        let logs = try ctx.fetch(FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.wordID == keptID }))
        #expect(logs.count == 1)
    }

    @Test("空组:删分组、返回 0")
    func emptyGroup() throws {
        let ctx = try makeContext()
        let pack = WordGroup(name: "商务英语", kind: WordGroup.kindPack, packSlug: "business")
        ctx.insert(pack)
        try ctx.save()

        let removed = WordPackRemover.remove(group: pack, in: ctx)

        #expect(removed == 0)
        let groups = try ctx.fetch(FetchDescriptor<WordGroup>())
        #expect(groups.isEmpty)
    }

    @Test("移除后同 slug 可重新导入(组不再存在)")
    func reimportableAfterRemoval() throws {
        let ctx = try makeContext()
        let pack = WordGroup(name: "旅游娱乐", kind: WordGroup.kindPack, packSlug: "travel")
        ctx.insert(pack)
        insertWord("visa", group: pack, in: ctx)
        try ctx.save()

        _ = WordPackRemover.remove(group: pack, in: ctx)

        let slug = "travel"
        let remaining = try ctx.fetch(
            FetchDescriptor<WordGroup>(predicate: #Predicate { $0.kind == "pack" && $0.packSlug == slug })
        )
        #expect(remaining.isEmpty)
    }
}
