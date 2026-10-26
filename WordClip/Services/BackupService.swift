import Foundation
import SwiftData
import WordClipKit

/// 词库备份服务：导出为 JSON、从 JSON 智能合并导入。
/// 跨平台（macOS/iOS 通用），合并去重按 lemma，与 WordCollector.upsert 风格一致。
@MainActor
struct BackupService {

    let modelContext: ModelContext

    /// 手动收录组（惰性找/建）。恢复备份的词都归入手动组——备份是用户自己的词库，
    /// 与手动收录同源；去重也在手动组内进行，避免与懒人词包的同词条互相污染。
    private var manualGroupStore: WordPackStore { WordPackStore(modelContext: modelContext) }

    struct ImportResult: Sendable {
        var added: Int      // 新建词条数
        var merged: Int     // 合并到已有词条数
    }

    enum BackupError: LocalizedError {
        case decodeFailed
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .decodeFailed:
                return String(localized: "backup.error.decode", defaultValue: "Unrecognized file format")
            case .unsupportedVersion(let v):
                return String(localized: "backup.error.version", defaultValue: "Unsupported backup version: \(v)")
            }
        }
    }

    // MARK: - 导出

    /// 导出手动收录的词条为 JSON Data。exportedAt 由调用方传入。
    /// 只导手动组(含存量 group==nil 老词):词包词可随时重新导入、无需备份,
    /// 且导入侧固定归入手动组,两端语义对称,避免备份往返展平分组。
    func export(exportedAt: Date) throws -> Data {
        let entries = fetchManualEntries()
        let backup = WordBackup.from(entries: entries, exportedAt: exportedAt)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    // MARK: - 导入

    /// 从 JSON Data 智能合并导入。
    func importData(_ data: Data) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let backup = try? decoder.decode(WordBackup.self, from: data) else {
            throw BackupError.decodeFailed
        }
        guard backup.version <= WordBackup.currentVersion else {
            throw BackupError.unsupportedVersion(backup.version)
        }

        // 恢复目标固定为手动收录组：去重、归属都在此组内。
        let manualGroup = manualGroupStore.manualGroup()

        var result = ImportResult(added: 0, merged: 0)
        for dto in backup.words {
            let lemma = dto.lemma.lowercased()
            guard !lemma.isEmpty else { continue }

            if let existing = try fetchEntry(lemma: lemma, in: manualGroup) {
                merge(dto, into: existing)
                result.merged += 1
            } else {
                let entry = makeEntry(from: dto)
                entry.group = manualGroup
                modelContext.insert(entry)
                result.added += 1
            }
        }
        try modelContext.save()
        return result
    }

    // MARK: - Private

    /// 智能合并：空释义才补，复习进度取更优，收藏取或。
    private func merge(_ dto: WordDTO, into entry: WordEntry) {
        if (entry.definition?.isEmpty ?? true), let d = dto.definition { entry.definition = d }
        if (entry.definitionEn?.isEmpty ?? true), let d = dto.definitionEn { entry.definitionEn = d }
        if (entry.phonetic?.isEmpty ?? true), let p = dto.phonetic { entry.phonetic = p }

        // 复习进度取“更熟”的一方，避免导入旧备份让进度倒退
        entry.familiarity = max(entry.familiarity, dto.familiarity)
        entry.repetitions = max(entry.repetitions, dto.repetitions)
        entry.interval    = max(entry.interval, dto.interval)
        entry.easeFactor  = max(entry.easeFactor, dto.easeFactor)
        entry.isFavorite  = entry.isFavorite || dto.isFavorite

        // dueAt 取较早者（更早该复习），任一为 nil 取另一个
        switch (entry.dueAt, dto.dueAt) {
        case let (a?, b?): entry.dueAt = min(a, b)
        case (nil, let b?): entry.dueAt = b
        default: break
        }

        // 合并标签去重
        if !dto.tags.isEmpty {
            entry.tags = Array(Set(entry.tags).union(dto.tags)).sorted()
        }
    }

    private func makeEntry(from dto: WordDTO) -> WordEntry {
        let entry = WordEntry(headword: dto.headword, lemma: dto.lemma, language: dto.language)
        entry.definition = dto.definition
        entry.definitionEn = dto.definitionEn
        entry.phonetic = dto.phonetic
        entry.tags = dto.tags
        entry.createdAt = dto.createdAt
        entry.isFavorite = dto.isFavorite
        entry.familiarity = dto.familiarity
        entry.easeFactor = dto.easeFactor
        entry.interval = dto.interval
        entry.repetitions = dto.repetitions
        entry.dueAt = dto.dueAt
        entry.lastReviewedAt = dto.lastReviewedAt
        return entry
    }

    /// 在指定分组内按 lemma 查已有词条（恢复备份只在手动组内去重，
    /// 不会命中懒人词包里的同词条）。
    private func fetchEntry(lemma: String, in group: WordGroup) throws -> WordEntry? {
        let gid = group.id
        let descriptor = FetchDescriptor<WordEntry>(
            predicate: #Predicate { $0.lemma == lemma && $0.group?.id == gid }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// 手动收录词条:归属手动组的词,外加存量 group==nil 老词(语义上也是手动)。
    /// 启动时 migrateOrphansToManualGroup 通常已把 nil 词迁入手动组,这里再兜底一次。
    private func fetchManualEntries() -> [WordEntry] {
        let gid = manualGroupStore.manualGroup().id
        let descriptor = FetchDescriptor<WordEntry>(
            predicate: #Predicate { $0.group?.id == gid || $0.group == nil },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
