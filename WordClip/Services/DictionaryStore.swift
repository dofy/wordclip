import Foundation
import WordClipKit

/// 已安装的自定义词典元数据（持久化到 UserDefaults）。
struct InstalledDictionary: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String        // 显示名（默认取文件名）
    var fileName: String    // Dictionaries/ 下的 sqlite 文件名
    var wordCount: Int
    var enabled: Bool

    init(id: UUID = UUID(), name: String, fileName: String, wordCount: Int, enabled: Bool = true) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.wordCount = wordCount
        self.enabled = enabled
    }
}

/// 管理内置 + 用户导入词典：导入、删除、排序、组装 CompositeDictionaryProvider。
/// 元数据存 UserDefaults，词库文件存 Application Support/WordClip/Dictionaries/。
@MainActor
final class DictionaryStore: ObservableObject {
    static let shared = DictionaryStore()

    @Published private(set) var installed: [InstalledDictionary] = []

    private let defaultsKey = "installedDictionaries"

    private init() {
        load()
    }

    // MARK: 目录

    /// Application Support/WordClip/Dictionaries/
    private var dictionariesDir: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("WordClip/Dictionaries", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func url(for dict: InstalledDictionary) -> URL {
        dictionariesDir.appendingPathComponent(dict.fileName)
    }

    // MARK: 持久化

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let list = try? JSONDecoder().decode([InstalledDictionary].self, from: data)
        else { return }
        installed = list
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(installed) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    // MARK: 导入 / 删除

    /// 从用户选择的文件导入一本词典（CSV/TSV/ECDICT SQLite）。
    /// 解析在后台线程完成，避免阻塞主线程。
    func importDictionary(from sourceURL: URL, displayName: String? = nil) async throws {
        let fileName = "\(UUID().uuidString).sqlite"
        let destPath = dictionariesDir.appendingPathComponent(fileName).path

        // fileImporter 返回的 URL 需要 security scope
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

        let result = try await Task.detached(priority: .userInitiated) {
            try DictionaryImporter.import(from: sourceURL, to: destPath)
        }.value

        let name = displayName ?? sourceURL.deletingPathExtension().lastPathComponent
        installed.append(InstalledDictionary(
            name: name, fileName: fileName, wordCount: result.wordCount
        ))
        persist()
    }

    func remove(_ dict: InstalledDictionary) {
        try? FileManager.default.removeItem(at: url(for: dict))
        installed.removeAll { $0.id == dict.id }
        persist()
    }

    func setEnabled(_ dict: InstalledDictionary, _ enabled: Bool) {
        guard let idx = installed.firstIndex(where: { $0.id == dict.id }) else { return }
        installed[idx].enabled = enabled
        persist()
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        installed.move(fromOffsets: fromOffsets, toOffset: toOffset)
        persist()
    }

    // MARK: 组装词库

    /// 组装组合词库：内置词典优先，其后按列表顺序叠加已启用的用户词典。
    /// 任一词库打开失败时跳过（不影响其他）。
    func buildProvider(builtin: DictionaryProvider) -> DictionaryProvider {
        var providers: [DictionaryProvider] = [builtin]
        for dict in installed where dict.enabled {
            if let p = try? GRDBDictionaryProvider(dbPath: url(for: dict).path) {
                providers.append(p)
            }
        }
        return providers.count == 1 ? builtin : CompositeDictionaryProvider(providers)
    }
}
