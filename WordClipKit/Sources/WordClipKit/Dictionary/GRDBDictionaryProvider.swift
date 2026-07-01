import Foundation
import GRDB

// MARK: - GRDBDictionaryProvider

/// 基于本地 SQLite（ECDICT 构建产物）的词库实现。
/// 数据库文件在 App 首次启动时从 Bundle 拷贝到 Application Support，只读打开。
public final class GRDBDictionaryProvider: DictionaryProvider {

    private let dbPool: DatabasePool

    /// - Parameter dbPath: SQLite 文件路径（Application Support 下的副本）
    public init(dbPath: String) throws {
        var config = Configuration()
        config.readonly = true
        self.dbPool = try DatabasePool(path: dbPath, configuration: config)
    }

    // MARK: DictionaryProvider

    public func lookup(_ word: String) async -> DictionaryResult? {
        let key = word.lowercased().trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }

        // 1. 精确匹配
        if let exact = try? await dbPool.read({ db in
            try Row.fetchOne(
                db,
                sql: """
                    SELECT word, lemma, phonetic, definition, definition_en, pos, exchange, freq_rank
                    FROM entries WHERE word = ? LIMIT 1
                """,
                arguments: [key]
            ).map { Self.result(from: $0) }
        }) {
            return exact
        }

        // 2. 变形还原 fallback：exchange 字段记录「原形 → 各变形」，
        //    如 bring 的 exchange 含 d:brought/p:brought/i:bringing/3:brings。
        //    用 :值/ 与 :值(结尾) 两种边界精确匹配，避免子串误命中。
        if key.count >= 2 {
            let inflected: DictionaryResult?? = try? await dbPool.read { db in
                try Row.fetchOne(
                    db,
                    sql: """
                        SELECT word, lemma, phonetic, definition, definition_en, pos, exchange, freq_rank
                        FROM entries
                        WHERE exchange LIKE ? OR exchange LIKE ?
                        ORDER BY freq_rank ASC
                        LIMIT 1
                    """,
                    arguments: ["%:\(key)/%", "%:\(key)"]
                ).map { row -> DictionaryResult in
                    let base = Self.result(from: row)
                    // 标注实际原形，让用户知道这是词形还原结果
                    guard let def = base.definition else { return base }
                    let baseWord: String = row["word"]
                    return DictionaryResult(
                        word:         key,
                        lemma:        baseWord,
                        phonetic:     base.phonetic,
                        definition:   "[\(baseWord)] \(def)",
                        definitionEn: base.definitionEn,
                        pos:          base.pos,
                        exchange:     base.exchange,
                        freqRank:     base.freqRank
                    )
                }
            }
            if let hit = inflected ?? nil { return hit }
        }

        // 3. 前缀 fallback：取前缀匹配里词频最高的候选词（freq_rank 最小）
        //    适合 config→configuration、app→application 等技术缩写场景
        guard key.count >= 3 else { return nil }   // 太短的词不做前缀扩展
        return try? await dbPool.read { db in
            try Row.fetchOne(
                db,
                sql: """
                    SELECT word, lemma, phonetic, definition, definition_en, pos, exchange, freq_rank
                    FROM entries
                    WHERE word LIKE ? ESCAPE '\\'
                    ORDER BY freq_rank ASC
                    LIMIT 1
                """,
                arguments: ["\(key)%"]
            ).map { row -> DictionaryResult in
                var r = Self.result(from: row)
                // 在释义前标注实际匹配到的词，让用户知道来源
                let matched: String = row["word"]
                if matched != key, let def = r.definition {
                    r = DictionaryResult(
                        word:         key,
                        lemma:        r.lemma,
                        phonetic:     r.phonetic,
                        definition:   "[\(matched)] \(def)",
                        definitionEn: r.definitionEn,
                        pos:          r.pos,
                        exchange:     r.exchange,
                        freqRank:     r.freqRank
                    )
                }
                return r
            }
        }
    }

    public func suggest(prefix: String, limit: Int) async -> [String] {
        let key = prefix.lowercased().trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return [] }
        return (try? await dbPool.read { db in
            try String.fetchAll(
                db,
                sql: """
                    SELECT word FROM entries
                    WHERE word LIKE ? ESCAPE '\\'
                    ORDER BY freq_rank ASC
                    LIMIT ?
                """,
                arguments: ["\(key)%", limit]
            )
        }) ?? []
    }

    // MARK: Private

    private static func result(from row: Row) -> DictionaryResult {
        DictionaryResult(
            word:         row["word"],
            lemma:        row["lemma"],
            phonetic:     row["phonetic"],
            definition:   row["definition"],
            definitionEn: row["definition_en"],
            pos:          row["pos"],
            exchange:     row["exchange"],
            freqRank:     row["freq_rank"]
        )
    }
}

// MARK: - Database setup helper

public enum DictionarySetup {

    /// App 启动时调用：把 Bundle 里的词库拷到 Application Support（只拷一次）。
    /// 返回可读写路径供 `GRDBDictionaryProvider` 使用。
    public static func prepareDatabasePath(
        bundleResource: String = "dictionary-en",
        fileExtension: String = "sqlite"
    ) throws -> String {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("WordClip", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)

        let dest = dir.appendingPathComponent("\(bundleResource).\(fileExtension)")
        if !fm.fileExists(atPath: dest.path) {
            guard let src = Bundle.main.url(
                forResource: bundleResource, withExtension: fileExtension
            ) else {
                throw DictionaryError.bundleResourceNotFound(bundleResource)
            }
            try fm.copyItem(at: src, to: dest)
        }
        return dest.path
    }
}

// MARK: - Errors

public enum DictionaryError: Error, LocalizedError {
    case bundleResourceNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .bundleResourceNotFound(let name):
            return "词库文件 \(name) 在 App Bundle 中不存在"
        }
    }
}
