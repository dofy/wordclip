import Foundation
import GRDB

// MARK: - DictionaryImporter

/// 把用户提供的词典文件导入成本 App 可用的 SQLite（entries 表，与内置同结构）。
/// 支持：
/// - CSV：`word,definition[,phonetic]`（逗号或制表符分隔，首行可为表头）
/// - ECDICT SQLite：已含 entries 表则校验后直接采用（拷贝到目标路径）
public enum DictionaryImporter {

    public enum ImportError: Error, LocalizedError {
        case unreadable
        case emptyOrInvalid
        case unsupported(String)

        public var errorDescription: String? {
            switch self {
            case .unreadable:            return "无法读取所选文件"
            case .emptyOrInvalid:        return "文件为空或没有可解析的词条"
            case .unsupported(let ext):  return "不支持的文件类型：.\(ext)"
            }
        }
    }

    public struct ImportResult: Sendable {
        public let path: String     // 生成/采用的 SQLite 路径
        public let wordCount: Int
    }

    /// 根据扩展名分派导入。`sourceURL` 为用户选择的文件，`destPath` 为目标 SQLite 路径。
    @discardableResult
    public static func `import`(from sourceURL: URL, to destPath: String) throws -> ImportResult {
        let ext = sourceURL.pathExtension.lowercased()
        switch ext {
        case "csv", "tsv", "txt":
            return try importCSV(from: sourceURL, to: destPath)
        case "sqlite", "db", "sqlite3":
            return try adoptSQLite(from: sourceURL, to: destPath)
        default:
            throw ImportError.unsupported(ext)
        }
    }

    // MARK: - CSV

    static func importCSV(from sourceURL: URL, to destPath: String) throws -> ImportResult {
        // UTF-8 优先,失败回退 ISO-8859-1(容忍非 UTF-8 的 CSV,不至于整份拒收)。
        guard let raw = (try? String(contentsOf: sourceURL, encoding: .utf8))
                ?? (try? String(contentsOf: sourceURL, encoding: .isoLatin1)) else {
            throw ImportError.unreadable
        }
        let rows = parseCSV(raw)
        guard !rows.isEmpty else { throw ImportError.emptyOrInvalid }

        try? FileManager.default.removeItem(atPath: destPath)
        let queue = try DatabaseQueue(path: destPath)
        try queue.write { db in
            try createSchema(db)
            for row in rows {
                try db.execute(
                    sql: "INSERT INTO entries (word, lemma, definition, phonetic, freq_rank) VALUES (?, ?, ?, ?, ?)",
                    arguments: [row.word, row.word.lowercased(), row.definition, row.phonetic, 999999]
                )
            }
        }
        return ImportResult(path: destPath, wordCount: rows.count)
    }

    struct CSVRow: Equatable {
        let word: String
        let definition: String
        let phonetic: String?
    }

    /// 解析 CSV/TSV：支持逗号或制表符分隔、双引号包裹、"" 转义。
    /// 列序：word, definition, phonetic(可选)。跳过空行与疑似表头。
    static func parseCSV(_ raw: String) -> [CSVRow] {
        var rows: [CSVRow] = []
        let lines = raw.split(whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" })
        for (idx, rawLine) in lines.enumerated() {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let sep: Character = line.contains("\t") ? "\t" : ","
            let fields = splitCSVLine(line, separator: sep)
            guard fields.count >= 2 else { continue }
            let word = fields[0].trimmingCharacters(in: .whitespaces)
            let def = fields[1].trimmingCharacters(in: .whitespaces)
            guard !word.isEmpty, !def.isEmpty else { continue }
            // 跳过表头行（首行且字段名像 header）
            if idx == 0 {
                let w = word.lowercased()
                if w == "word" || w == "headword" || w == "单词" { continue }
            }
            let phonetic = fields.count >= 3
                ? fields[2].trimmingCharacters(in: .whitespaces).nilIfEmpty
                : nil
            rows.append(CSVRow(word: word, definition: def, phonetic: phonetic))
        }
        return rows
    }

    /// 单行 CSV 拆分（处理双引号包裹与 "" 转义）。
    private static func splitCSVLine(_ line: String, separator: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        var pending: Character? = iterator.next()
        while let ch = pending {
            pending = iterator.next()
            if inQuotes {
                if ch == "\"" {
                    if pending == "\"" {        // 转义的引号
                        current.append("\"")
                        pending = iterator.next()
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(ch)
                }
            } else {
                if ch == "\"" {
                    inQuotes = true
                } else if ch == separator {
                    fields.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
            }
        }
        fields.append(current)
        return fields
    }

    // MARK: - ECDICT SQLite

    /// 校验来源 SQLite 含 entries(word, definition) 表后，拷贝到目标路径采用。
    static func adoptSQLite(from sourceURL: URL, to destPath: String) throws -> ImportResult {
        // 先在源文件上只读校验结构
        var config = Configuration()
        config.readonly = true
        let srcQueue: DatabaseQueue
        do {
            srcQueue = try DatabaseQueue(path: sourceURL.path, configuration: config)
        } catch {
            throw ImportError.unreadable
        }
        let count: Int = try srcQueue.read { db in
            let hasTable = try Bool.fetchOne(
                db, sql: "SELECT count(*) > 0 FROM sqlite_master WHERE type='table' AND name='entries'"
            ) ?? false
            guard hasTable else { throw ImportError.unsupported("sqlite（缺少 entries 表）") }
            // 校验必需列
            let cols = try Row.fetchAll(db, sql: "PRAGMA table_info(entries)").map { $0["name"] as String }
            guard cols.contains("word"), cols.contains("definition") else {
                throw ImportError.unsupported("sqlite（entries 缺少 word/definition 列）")
            }
            return try Int.fetchOne(db, sql: "SELECT count(*) FROM entries") ?? 0
        }
        guard count > 0 else { throw ImportError.emptyOrInvalid }

        try? FileManager.default.removeItem(atPath: destPath)
        try FileManager.default.copyItem(atPath: sourceURL.path, toPath: destPath)
        return ImportResult(path: destPath, wordCount: count)
    }

    // MARK: - Schema

    /// 与内置词库一致的 entries 结构（含索引）。
    static func createSchema(_ db: Database) throws {
        try db.execute(sql: """
            CREATE TABLE entries (
                id INTEGER PRIMARY KEY,
                word TEXT NOT NULL,
                lemma TEXT,
                phonetic TEXT,
                definition TEXT,
                definition_en TEXT,
                pos TEXT,
                exchange TEXT,
                freq_rank INTEGER DEFAULT 999999
            );
        """)
        try db.execute(sql: "CREATE INDEX idx_word ON entries(word);")
        try db.execute(sql: "CREATE INDEX idx_lemma ON entries(lemma);")
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
