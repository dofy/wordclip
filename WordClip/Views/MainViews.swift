import SwiftUI
import SwiftData
import WordClipKit
import UniformTypeIdentifiers
#if os(macOS)
import KeyboardShortcuts
#endif

/// macOS 侧边栏
struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Label(String(localized: "sidebar.allwords", defaultValue: "全部单词"), systemImage: "books.vertical")
                .tag(SidebarItem.allWords)
            Label(String(localized: "sidebar.review", defaultValue: "复习"), systemImage: "checkmark.circle")
                .tag(SidebarItem.review)
            Label(String(localized: "sidebar.settings", defaultValue: "设置"), systemImage: "gearshape")
                .tag(SidebarItem.settings)
        }
        .navigationTitle(String(localized: "app.name", defaultValue: "WordClip"))
        .listStyle(.sidebar)
    }
}

/// 词典列表页：支持查看详情、删除、修复释义（单条 + 批量）。
struct WordListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \WordEntry.createdAt, order: .reverse) private var words: [WordEntry]

    @State private var selectedWord: WordEntry?      // 详情 sheet
    @State private var selection = Set<WordEntry.ID>() // 多选
    @State private var isRepairing = false
    @State private var repairMessage: String?
    @State private var pendingDelete: [WordEntry] = []  // 待确认删除
    @State private var showDeleteConfirm = false
    @State private var searchText = ""

    private var actions: WordListActions {
        WordListActions(modelContext: modelContext, dictionary: appState.dictionary)
    }

    /// 空状态描述文案：macOS 用全局快捷键，iOS 用快捷指令/分享。
    private var emptyDescription: String {
        #if os(macOS)
        String(localized: "wordlist.empty.description",
               defaultValue: "在任意 App 中选中单词，用快捷键一键收录")
        #else
        String(localized: "wordlist.empty.description.ios",
               defaultValue: "通过快捷指令或分享菜单，把生词收录到 WordClip")
        #endif
    }

    /// 按搜索词过滤：匹配单词或释义（不区分大小写）。
    private var filteredWords: [WordEntry] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return words }
        return words.filter { word in
            word.headword.lowercased().contains(q)
                || word.lemma.contains(q)
                || (word.definition?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        Group {
            if words.isEmpty {
                ContentUnavailableView(
                    String(localized: "wordlist.empty.title", defaultValue: "还没有收藏的单词"),
                    systemImage: "books.vertical",
                    description: Text(emptyDescription)
                )
            } else if filteredWords.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(selection: $selection) {
                    ForEach(filteredWords) { word in
                        row(for: word)
                            .tag(word.id)
                            .contextMenu {
                                Button {
                                    selectedWord = word
                                } label: {
                                    Label(String(localized: "wordlist.menu.detail", defaultValue: "查看详情"),
                                          systemImage: "info.circle")
                                }
                                Button {
                                    Task { await repairOne(word) }
                                } label: {
                                    Label(String(localized: "wordlist.menu.repair", defaultValue: "修复释义"),
                                          systemImage: "arrow.clockwise")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    requestDelete([word])
                                } label: {
                                    Label(String(localized: "wordlist.menu.delete", defaultValue: "删除"),
                                          systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in
                        requestDelete(offsets.map { filteredWords[$0] })
                    }
                }
            }
        }
        .navigationTitle(String(localized: "tab.wordlist", defaultValue: "词典"))
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: String(localized: "wordlist.search.prompt", defaultValue: "搜索单词或释义")
        )
        .toolbar {
            ToolbarItemGroup {
                if !selection.isEmpty {
                    // 批量删除选中
                    Button(role: .destructive) {
                        let toDelete = words.filter { selection.contains($0.id) }
                        requestDelete(toDelete)
                    } label: {
                        Label(String(localized: "wordlist.toolbar.delete.selected",
                                     defaultValue: "删除选中 (\(selection.count))"),
                              systemImage: "trash")
                    }
                }
                // 批量修复无释义
                Button {
                    Task { await repairAll() }
                } label: {
                    if isRepairing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(String(localized: "wordlist.toolbar.repair.all", defaultValue: "修复无释义"),
                              systemImage: "wand.and.stars")
                    }
                }
                .disabled(isRepairing || appState.dictionary == nil)
            }
        }
        .overlay(alignment: .bottom) {
            if let msg = repairMessage {
                Text(msg)
                    .font(.callout)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 4, y: 2)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: repairMessage)
        .sheet(item: $selectedWord) { word in
            WordDetailView(word: word, onRepair: { await repairOne(word) })
        }
        .confirmationDialog(
            deleteConfirmTitle,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "delete.confirm", defaultValue: "删除"), role: .destructive) {
                actions.delete(pendingDelete)
                selection.removeAll()
                pendingDelete = []
            }
            Button(String(localized: "delete.cancel", defaultValue: "取消"), role: .cancel) {
                pendingDelete = []
            }
        }
    }

    private var deleteConfirmTitle: String {
        if pendingDelete.count == 1 {
            return String(localized: "delete.confirm.one",
                          defaultValue: "确定删除「\(pendingDelete.first?.headword ?? "")」？")
        }
        return String(localized: "delete.confirm.many",
                      defaultValue: "确定删除选中的 \(pendingDelete.count) 个单词？")
    }

    private func requestDelete(_ targets: [WordEntry]) {
        guard !targets.isEmpty else { return }
        pendingDelete = targets
        showDeleteConfirm = true
    }

    @ViewBuilder
    private func row(for word: WordEntry) -> some View {
        Button {
            selectedWord = word
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(word.headword)
                        .font(.headline)
                    if let phonetic = word.phonetic, !phonetic.isEmpty {
                        Text("/\(phonetic)/")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                if let definition = word.definition, !definition.isEmpty {
                    Text(definition.components(separatedBy: "\n").first ?? definition)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(String(localized: "wordlist.nodef", defaultValue: "暂无释义"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                requestDelete([word])
            } label: {
                Label(String(localized: "wordlist.menu.delete", defaultValue: "删除"), systemImage: "trash")
            }
        }
    }

    // MARK: - 修复操作

    private func repairOne(_ word: WordEntry) async {
        let ok = await actions.repair(word)
        flashRepair(ok
            ? String(localized: "repair.one.success", defaultValue: "已更新：\(word.headword)")
            : String(localized: "repair.one.fail", defaultValue: "词典未收录：\(word.headword)"))
    }

    private func repairAll() async {
        isRepairing = true
        let count = await actions.repairAll(words)
        isRepairing = false
        flashRepair(String(localized: "repair.all.done", defaultValue: "已修复 \(count) 个词条"))
    }

    private func flashRepair(_ message: String) {
        repairMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if repairMessage == message { repairMessage = nil }
        }
    }
}

/// 单词详情：展示完整释义、音标、来源。
struct WordDetailView: View {
    let word: WordEntry
    var onRepair: (() async -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var isRepairing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.headword)
                        .font(.largeTitle.bold())
                    if let phonetic = word.phonetic, !phonetic.isEmpty {
                        Text("/\(phonetic)/")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let definition = word.definition, !definition.isEmpty {
                        Text(definition)
                            .font(.body)
                            .textSelection(.enabled)
                    } else {
                        Text(String(localized: "wordlist.nodef", defaultValue: "暂无释义"))
                            .foregroundStyle(.secondary)
                    }

                    if let en = word.definitionEn, !en.isEmpty {
                        Text(en)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            HStack {
                if !word.sources.isEmpty {
                    Text(String(localized: "detail.collected.count", defaultValue: "收录 \(word.sources.count) 次"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if let onRepair {
                    Button {
                        Task {
                            isRepairing = true
                            await onRepair()
                            isRepairing = false
                        }
                    } label: {
                        if isRepairing {
                            ProgressView().controlSize(.small)
                        } else {
                            Label(String(localized: "detail.repair", defaultValue: "修复释义"),
                                  systemImage: "arrow.clockwise")
                        }
                    }
                    .controlSize(.small)
                    .disabled(isRepairing)
                }
            }
        }
        .padding(24)
        .frame(width: 420, height: 360)
    }
}

/// 设置页
struct SettingsView: View {
    @EnvironmentObject private var entitlement: MockEntitlement
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext

    #if os(macOS)
    // macOS 26+ 上 name 式 Recorder 失效，改用 binding 式录制器，
    // 在 onChange 中把快捷键写回 .collectWord 名称的存储，保证全局监听照常生效。
    @State private var collectShortcut: KeyboardShortcuts.Shortcut? = KeyboardShortcuts.getShortcut(for: .collectWord)
    #endif

    // 备份导出/导入
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportDocument: WordBackupDocument?
    @State private var backupMessage: String?

    private var backup: BackupService {
        BackupService(modelContext: modelContext)
    }

    var body: some View {
        Form {
            #if os(macOS)
            // ── 取词（仅 macOS）──────────────────────────────
            Section {
                Toggle(
                    String(localized: "settings.capture.enabled", defaultValue: "启用全局取词"),
                    isOn: $appState.captureEnabled
                )

                LabeledContent(String(localized: "settings.capture.shortcut", defaultValue: "取词快捷键")) {
                    ShortcutRecorderField(shortcut: $collectShortcut)
                }
                .onChange(of: collectShortcut) { _, newValue in
                    KeyboardShortcuts.setShortcut(newValue, for: .collectWord)
                    appState.refreshHotkeyRegistration()
                }
            } header: {
                Text(String(localized: "settings.section.capture", defaultValue: "取词"))
            } footer: {
                Text(String(localized: "settings.capture.hint",
                    defaultValue: "在任意 App 中选中单词，按下快捷键即可收录到 WordClip"))
                .foregroundStyle(.secondary)
            }

            // ── 通用（仅 macOS）──────────────────────────────
            Section {
                Toggle(
                    String(localized: "settings.general.launchatlogin", defaultValue: "登录时自动启动"),
                    isOn: $appState.launchAtLogin
                )
            } header: {
                Text(String(localized: "settings.section.general", defaultValue: "通用"))
            }
            #endif

            // ── 账户 ──────────────────────────────────────
            Section {
                LabeledContent(
                    String(localized: "settings.plan", defaultValue: "当前方案"),
                    value: entitlement.isPro
                        ? String(localized: "settings.plan.pro", defaultValue: "Pro")
                        : String(localized: "settings.plan.free", defaultValue: "免费版")
                )
            } header: {
                Text(String(localized: "settings.account", defaultValue: "账户"))
            }

            // ── 数据（导出/导入）──────────────────────────
            Section {
                Button {
                    exportBackup()
                } label: {
                    Label(String(localized: "settings.export", defaultValue: "导出词库"),
                          systemImage: "square.and.arrow.up")
                }
                Button {
                    showingImporter = true
                } label: {
                    Label(String(localized: "settings.import", defaultValue: "导入词库"),
                          systemImage: "square.and.arrow.down")
                }
            } header: {
                Text(String(localized: "settings.section.data", defaultValue: "数据"))
            } footer: {
                Text(String(localized: "settings.data.hint",
                    defaultValue: "导出为 JSON 文件备份，或在新设备导入。导入按单词智能合并，不会覆盖已有的学习进度。"))
                .foregroundStyle(.secondary)
            }

            #if DEBUG
            Section {
                Toggle(
                    String(localized: "settings.debug.pro", defaultValue: "模拟 Pro（调试）"),
                    isOn: $entitlement.isPro
                )
            } header: {
                Text("Debug")
            }
            #endif
        }
        .navigationTitle(String(localized: "tab.settings", defaultValue: "设置"))
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
                flashBackup(String(localized: "backup.export.fail",
                                   defaultValue: "导出失败：\(error.localizedDescription)"))
            } else {
                flashBackup(String(localized: "backup.export.ok", defaultValue: "已导出词库"))
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .overlay(alignment: .bottom) {
            if let msg = backupMessage {
                Text(msg)
                    .font(.callout)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 4, y: 2)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: backupMessage)
    }

    // MARK: - 备份操作

    private var exportFilename: String {
        "wordclip-backup"
    }

    private func exportBackup() {
        do {
            let data = try backup.export(exportedAt: Date())
            exportDocument = WordBackupDocument(data: data)
            showingExporter = true
        } catch {
            flashBackup(String(localized: "backup.export.fail",
                               defaultValue: "导出失败：\(error.localizedDescription)"))
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        // fileImporter 返回的 URL 需要 security scope 访问
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let r = try backup.importData(data)
            flashBackup(String(localized: "backup.import.result",
                               defaultValue: "已导入：新增 \(r.added)，合并 \(r.merged)"))
        } catch {
            flashBackup(String(localized: "backup.import.fail",
                               defaultValue: "导入失败：\(error.localizedDescription)"))
        }
    }

    private func flashBackup(_ message: String) {
        backupMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if backupMessage == message { backupMessage = nil }
        }
    }
}
