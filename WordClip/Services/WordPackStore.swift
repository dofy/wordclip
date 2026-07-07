import Foundation
import SwiftData
import WordClipKit

/// 词包落库:找/建 WordGroup,把 DTO 词写入 SwiftData(组内去重、幂等)。
@MainActor
final class WordPackStore {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// 找或建「手动收录」组。
    func manualGroup() -> WordGroup {
        if let g = fetchGroup(kind: WordGroup.kindManual, slug: nil) { return g }
        let g = WordGroup(name: WordGroup.manualGroupName, kind: WordGroup.kindManual, sortOrder: 0)
        modelContext.insert(g)
        try? modelContext.save()
        return g
    }

    /// 一次性迁移:把 group == nil 的存量老词归入「手动收录」组。
    /// 幂等:没有 nil 词时不写入、返回 0。分支引入 group 字段前收录的词迁移后为 nil,
    /// 本方法让它们进入手动组,使「== 手动组id」的查询谓词对存量词也成立。
    @discardableResult
    func migrateOrphansToManualGroup() -> Int {
        let descriptor = FetchDescriptor<WordEntry>(predicate: #Predicate { $0.group == nil })
        let orphans = (try? modelContext.fetch(descriptor)) ?? []
        guard !orphans.isEmpty else { return 0 }
        let group = manualGroup()
        for entry in orphans { entry.group = group }
        try? modelContext.save()
        return orphans.count
    }

    func isImported(slug: String) -> Bool { importedCount(slug: slug) > 0 }

    func importedCount(slug: String) -> Int {
        guard let g = fetchGroup(kind: WordGroup.kindPack, slug: slug) else { return 0 }
        let gid = g.id
        let d = FetchDescriptor<WordEntry>(predicate: #Predicate { $0.group?.id == gid })
        return (try? modelContext.fetchCount(d)) ?? 0
    }

    /// 导入词包,返回新增词数。幂等:重复导入只补差集。
    @discardableResult
    func `import`(_ pack: WordPackDTO) -> Int {
        // 找/建目标组
        let group: WordGroup
        if let g = fetchGroup(kind: WordGroup.kindPack, slug: pack.slug) {
            group = g
        } else {
            group = WordGroup(name: pack.name, kind: WordGroup.kindPack,
                              packSlug: pack.slug, iconSymbol: pack.icon, sortOrder: 1)
            modelContext.insert(group)
        }

        // 本组已有 lemma 集合
        let gid = group.id
        let existing = (try? modelContext.fetch(
            FetchDescriptor<WordEntry>(predicate: #Predicate { $0.group?.id == gid })
        )) ?? []
        let existingLemmas = Set(existing.map { $0.lemma.lowercased() })

        let newWords = WordPackImporter.newWords(in: pack, existingLemmas: existingLemmas)
        for w in newWords {
            let entry = WordEntry(headword: w.headword, lemma: w.lemma.lowercased(), language: pack.language)
            entry.definition = w.definition
            entry.definitionEn = w.definitionEn
            entry.phonetic = w.phonetic
            entry.group = group      // 全新词:lastReviewedAt 默认 nil
            modelContext.insert(entry)
        }
        try? modelContext.save()
        return newWords.count
    }

    private func fetchGroup(kind: String, slug: String?) -> WordGroup? {
        let d: FetchDescriptor<WordGroup>
        if let slug {
            d = FetchDescriptor<WordGroup>(predicate: #Predicate { $0.kind == kind && $0.packSlug == slug })
        } else {
            d = FetchDescriptor<WordGroup>(predicate: #Predicate { $0.kind == kind })
        }
        return try? modelContext.fetch(d).first
    }
}
