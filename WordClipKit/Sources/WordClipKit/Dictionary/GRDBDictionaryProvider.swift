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
        return try? await dbPool.read { db in
            try Row.fetchOne(
                db,
                sql: """
                    SELECT word, lemma, phonetic, definition, definition_en, pos, exchange, freq_rank
                    FROM entries
                    WHERE word = ?
                    LIMIT 1
                """,
                arguments: [key]
            ).map { Self.result(from: $0) }
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
