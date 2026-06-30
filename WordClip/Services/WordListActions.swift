import Foundation
import SwiftData
import WordClipKit

/// 词条管理操作：删除、修复释义（单条/批量）。
@MainActor
struct WordListActions {

    let modelContext: ModelContext
    let dictionary: (any DictionaryProvider)?

    // MARK: - 删除

    func delete(_ words: [WordEntry]) {
        for word in words {
            modelContext.delete(word)
        }
        try? modelContext.save()
    }

    func delete(_ word: WordEntry) {
        delete([word])
    }

    // MARK: - 修复释义

    /// 重新查词典，补充/更新单个词条的释义。
    /// - Returns: 是否成功查到并更新了释义
    @discardableResult
    func repair(_ word: WordEntry) async -> Bool {
        guard let dictionary else { return false }
        guard let result = await dictionary.lookup(word.lemma) else { return false }

        word.definition = result.definition
        word.definitionEn = result.definitionEn
        if let ph = result.phonetic, !ph.isEmpty {
            word.phonetic = ph
        }
        try? modelContext.save()
        return result.definition != nil
    }

    /// 批量修复所有释义为空的词条。
    /// - Returns: 成功修复的数量
    @discardableResult
    func repairAll(_ words: [WordEntry]) async -> Int {
        guard dictionary != nil else { return 0 }
        var fixed = 0
        for word in words where (word.definition?.isEmpty ?? true) {
            if await repair(word) { fixed += 1 }
        }
        return fixed
    }
}
