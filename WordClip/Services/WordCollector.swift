#if os(macOS)
import Foundation
import SwiftData
import AppKit
import NaturalLanguage
import WordClipKit

/// 取词收录服务：选中文本 → 查本地词典 → 写入 SwiftData。
///
/// 设计要点：
/// - 查不到词仍收录（释义留空），不丢词。
/// - 按 lemma 去重：同一个词重复收集只新增一条 CollectSource，不重复建 WordEntry。
@MainActor
final class WordCollector {

    private let modelContext: ModelContext
    private let dictionary: DictionaryProvider

    init(modelContext: ModelContext, dictionary: DictionaryProvider) {
        self.modelContext = modelContext
        self.dictionary = dictionary
    }

    /// 收录结果，供调用方反馈用户。
    enum CollectOutcome: Sendable {
        case collected(word: String, found: Bool, definition: String?)
        case noSelection
        case notTrusted
        case invalid
    }

    /// 完整收词流程：读取选中文本 → 查词 → 入库。
    func collectFromSelection() async -> CollectOutcome {
        guard SelectionReader.isTrusted else { return .notTrusted }
        guard let raw = SelectionReader.selectedText() else { return .noSelection }

        // 取第一个单词（容忍用户选中了一个短语，但只收第一个词）
        guard let extracted = Self.extractWord(from: raw) else { return .invalid }

        let headword = Self.normalizeCase(extracted)
        let lemma = headword.lowercased()
        let result = await dictionary.lookup(lemma)
        let frontApp = NSWorkspace.shared.frontmostApplication

        upsert(headword: headword, lemma: lemma, dict: result, sourceApp: frontApp)

        return .collected(word: headword, found: result != nil, definition: result?.definition)
    }

    /// 直接按单词收录（供 URL scheme wordclip://collect?word= 调用）。
    func collect(word: String) async -> CollectOutcome {
        guard let extracted = Self.extractWord(from: word) else { return .invalid }
        let headword = Self.normalizeCase(extracted)
        let lemma = headword.lowercased()
        let result = await dictionary.lookup(lemma)
        upsert(headword: headword, lemma: lemma, dict: result, sourceApp: nil)
        return .collected(word: headword, found: result != nil, definition: result?.definition)
    }

    // MARK: - Private

    /// 写入或更新词条（按 lemma 去重，追加 CollectSource）。
    private func upsert(
        headword: String,
        lemma: String,
        dict: DictionaryResult?,
        sourceApp: NSRunningApplication?
    ) {
        let existing = fetchEntry(lemma: lemma)

        let entry: WordEntry
        if let existing {
            entry = existing
            // 重新收录时，若已有词条释义为空而本次查到了，补充更新
            if let dict {
                if (entry.definition?.isEmpty ?? true), let def = dict.definition {
                    entry.definition = def
                }
                if (entry.definitionEn?.isEmpty ?? true), let en = dict.definitionEn {
                    entry.definitionEn = en
                }
                if (entry.phonetic?.isEmpty ?? true), let ph = dict.phonetic {
                    entry.phonetic = ph
                }
            }
        } else {
            entry = WordEntry(headword: headword, lemma: lemma, language: "en")
            entry.definition = dict?.definition
            entry.definitionEn = dict?.definitionEn
            entry.phonetic = dict?.phonetic
            modelContext.insert(entry)
        }

        let source = CollectSource(
            platform: "macOS",
            appName: sourceApp?.localizedName,
            contextSentence: nil,
            bundleIdentifier: sourceApp?.bundleIdentifier
        )
        modelContext.insert(source)
        entry.sources.append(source)

        try? modelContext.save()
    }

    private func fetchEntry(lemma: String) -> WordEntry? {
        let descriptor = FetchDescriptor<WordEntry>(
            predicate: #Predicate { $0.lemma == lemma }
        )
        return try? modelContext.fetch(descriptor).first
    }

    /// 从原始选中文本中提取首个有效英文单词。
    static func extractWord(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // 取首个 token，去掉两端标点
        let token = trimmed.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? trimmed
        let cleaned = token.trimmingCharacters(in: CharacterSet.letters.inverted)
        // 必须以字母为主体
        guard cleaned.count >= 1,
              cleaned.allSatisfy({ $0.isLetter || $0 == "-" || $0 == "'" })
        else { return nil }
        return cleaned
    }

    /// 大小写归一化：用 NaturalLanguage 识别专有名词。
    /// 专有名词（国家/人名/组织等）保留首字母大写形式，其余一律转小写。
    static func normalizeCase(_ word: String) -> String {
        let lower = word.lowercased()

        // 用词性标注判断是否为专有名词
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = word

        var isProperNoun = false
        let range = word.startIndex..<word.endIndex

        // 命名实体识别：国家、人名、地名、组织
        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, _ in
            if let tag, [.personalName, .placeName, .organizationName].contains(tag) {
                isProperNoun = true
            }
            return true
        }

        // 词性标注：专有名词 (.noun 中的 Proper) — NL 没有单独 Proper 标签，
        // 用 nameType 已覆盖主要场景（国家、城市、人名、机构）。
        if isProperNoun {
            // 专有名词：首字母大写，其余小写（China、Beijing、English）
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }
        return lower
    }
}
#endif
