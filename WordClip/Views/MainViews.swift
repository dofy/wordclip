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
            Label(String(localized: "sidebar.stats", defaultValue: "统计"), systemImage: "chart.xyaxis.line")
                .tag(SidebarItem.stats)
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
    @State private var showingAddWord = false
    @State private var showFavoritesOnly = false
    @FocusState private var searchFocused: Bool

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

    /// 按搜索词过滤：匹配单词或释义（不区分大小写），可叠加只看收藏。
    private var filteredWords: [WordEntry] {
        var result = words
        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return result }
        return result.filter { word in
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
                                    open(word)
                                } label: {
                                    Label(String(localized: "wordlist.menu.detail", defaultValue: "查看详情"),
                                          systemImage: "info.circle")
                                }
                                Button {
                                    Speaker.shared.speak(word.headword)
                                } label: {
                                    Label(String(localized: "wordlist.menu.speak", defaultValue: "朗读"),
                                          systemImage: "speaker.wave.2")
                                }
                                Button {
                                    word.isFavorite.toggle()
                                    try? modelContext.save()
                                } label: {
                                    Label(word.isFavorite
                                          ? String(localized: "wordlist.menu.unfavorite", defaultValue: "取消收藏")
                                          : String(localized: "wordlist.menu.favorite", defaultValue: "收藏"),
                                          systemImage: word.isFavorite ? "star.slash" : "star")
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
                #if os(macOS)
                // 详情 sheet 打开时禁用列表级快捷键，避免与详情页 ⌘D/⌘R/⌘L 冲突
                .background(selectedWord == nil ? listShortcuts : nil)
                .onAppear {
                    if selection.isEmpty, let first = filteredWords.first {
                        selection = [first.id]
                    }
                }
                #endif
            }
        }
        .navigationTitle(String(localized: "tab.wordlist", defaultValue: "词典"))
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: String(localized: "wordlist.search.prompt", defaultValue: "搜索单词或释义")
        )
        .searchFocused($searchFocused)
        .background(searchFocusShortcuts)
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

                // 只看收藏
                Button {
                    showFavoritesOnly.toggle()
                } label: {
                    Label(String(localized: "wordlist.toolbar.favorites", defaultValue: "只看收藏"),
                          systemImage: showFavoritesOnly ? "star.fill" : "star")
                }
                .foregroundStyle(showFavoritesOnly ? .yellow : .secondary)

                // 添加单词
                Button {
                    showingAddWord = true
                } label: {
                    Label(String(localized: "wordlist.toolbar.add", defaultValue: "添加单词"),
                          systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddWord) {
            AddWordView()
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
            WordDetailView(
                words: filteredWords,
                current: $selectedWord,
                fallback: word,
                onRepair: { await repairOne($0) }
            )
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

    /// 打开词条详情（详情页内可继续上下切换）。
    private func open(_ word: WordEntry) {
        selectedWord = word
    }

    /// ⌘K / ⌘F 定位到搜索框。隐藏按钮承载快捷键。
    @ViewBuilder
    private var searchFocusShortcuts: some View {
        Group {
            Button("") { searchFocused = true }
                .keyboardShortcut("k", modifiers: .command)
            Button("") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    /// 当前快捷键作用的目标：多选时取全部选中，否则取首个选中项。
    private var selectedWords: [WordEntry] {
        let inSelection = filteredWords.filter { selection.contains($0.id) }
        return inSelection.isEmpty ? [] : inSelection
    }

    #if os(macOS)
    /// 隐藏按钮承载列表级快捷键，作用于当前选中词条。
    /// 回车打开、⌘L 朗读、⌘D 收藏、⌘R 修复、⌘⌫ 删除。
    @ViewBuilder
    private var listShortcuts: some View {
        Group {
            Button("") {
                if let w = selectedWords.first { open(w) }
            }
            .keyboardShortcut(.return, modifiers: [])

            Button("") {
                if let w = selectedWords.first { Speaker.shared.speak(w.headword) }
            }
            .keyboardShortcut("l", modifiers: .command)

            Button("") {
                let targets = selectedWords
                guard !targets.isEmpty else { return }
                // 有任一未收藏 → 全部收藏；否则全部取消
                let makeFav = targets.contains { !$0.isFavorite }
                targets.forEach { $0.isFavorite = makeFav }
                try? modelContext.save()
            }
            .keyboardShortcut("d", modifiers: .command)

            Button("") {
                let targets = selectedWords
                Task { for w in targets { await repairOne(w) } }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("") {
                requestDelete(selectedWords)
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .focusable(false)
        .accessibilityHidden(true)
    }
    #endif

    @ViewBuilder
    private func row(for word: WordEntry) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(word.headword)
                    .font(.headline)
                if let phonetic = word.phonetic, !phonetic.isEmpty {
                    Text("/\(phonetic)/")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if word.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        // 单击交给 List 选中；双击打开详情（iOS 单击即开，见下）
        #if os(macOS)
        .onTapGesture(count: 2) { open(word) }
        #else
        .onTapGesture { open(word) }
        #endif
        .swipeActions(edge: .leading) {
            Button {
                word.isFavorite.toggle()
                try? modelContext.save()
            } label: {
                Label(String(localized: "wordlist.menu.favorite", defaultValue: "收藏"),
                      systemImage: word.isFavorite ? "star.slash" : "star")
            }
            .tint(.yellow)
        }
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

/// 单词详情：展示完整释义、音标、来源，并支持在列表内上下切换词条。
struct WordDetailView: View {
    let words: [WordEntry]
    @Binding var current: WordEntry?
    /// 兜底：words 为空或找不到时显示的词条（sheet item 保证非 nil）。
    let fallback: WordEntry
    var onRepair: (@MainActor (WordEntry) async -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isRepairing = false

    /// 当前展示的词条。
    private var word: WordEntry { current ?? fallback }

    /// 当前词条在列表中的下标。
    private var index: Int? {
        words.firstIndex { $0.id == word.id }
    }

    private var canPrev: Bool { (index ?? 0) > 0 }
    private var canNext: Bool {
        guard let i = index else { return false }
        return i < words.count - 1
    }

    private func go(_ delta: Int) {
        guard let i = index else { return }
        let j = i + delta
        guard words.indices.contains(j) else { return }
        current = words[j]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            ScrollView {
                StructuredDefinitionView(
                    definition: word.definition,
                    definitionEn: word.definitionEn
                )
            }
            Divider()
            footer
            #if os(macOS)
            shortcutHint
            #endif
        }
        .padding(24)
        .background(navShortcuts)
        #if os(macOS)
        .frame(width: 440, height: 400)
        #else
        .frame(maxWidth: 520)
        .presentationDetents([.medium, .large])
        #endif
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text(word.headword)
                        .font(.largeTitle.bold())
                    iconButton("speaker.wave.2.fill", tint: .accentColor) {
                        Speaker.shared.speak(word.headword)
                    }
                    iconButton(word.isFavorite ? "star.fill" : "star",
                               tint: word.isFavorite ? .yellow : .secondary) {
                        word.isFavorite.toggle()
                        try? modelContext.save()
                    }
                }
                if let phonetic = word.phonetic, !phonetic.isEmpty {
                    Text("/\(phonetic)/")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                FamiliarityBadge(familiarity: word.familiarity)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                iconButton("xmark.circle.fill", font: .title2, tint: .secondary) {
                    dismiss()
                }
                if words.count > 1 {
                    HStack(spacing: 6) {
                        iconButton("chevron.up", tint: canPrev ? .secondary : Color.secondary.opacity(0.3)) {
                            go(-1)
                        }
                        .disabled(!canPrev)
                        iconButton("chevron.down", tint: canNext ? .secondary : Color.secondary.opacity(0.3)) {
                            go(1)
                        }
                        .disabled(!canNext)
                    }
                    if let i = index {
                        Text("\(i + 1) / \(words.count)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: 底部

    private var footer: some View {
        HStack {
            if !word.sources.isEmpty {
                Text(String(localized: "detail.collected.count", defaultValue: "收录 \(word.sources.count) 次"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if onRepair != nil {
                Button {
                    runRepair()
                } label: {
                    if isRepairing {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(String(localized: "detail.repair", defaultValue: "修复释义"),
                              systemImage: "arrow.clockwise")
                    }
                }
                .controlSize(.small)
                .focusable(false)
                .disabled(isRepairing)
            }
        }
    }

    #if os(macOS)
    /// 底部一行快捷键提示，提升可发现性。
    private var shortcutHint: some View {
        Text(words.count > 1
             ? String(localized: "detail.shortcuts.nav",
                      defaultValue: "↑↓ 切换 · ⌘L 朗读 · ⌘D 收藏 · ⌘R 修复")
             : String(localized: "detail.shortcuts",
                      defaultValue: "⌘L 朗读 · ⌘D 收藏 · ⌘R 修复"))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .center)
    }
    #endif

    private func runRepair() {
        guard let onRepair else { return }
        let target = word
        Task {
            isRepairing = true
            await onRepair(target)
            isRepairing = false
        }
    }

    /// 统一的纯图标按钮：无焦点框、plain 样式。
    @ViewBuilder
    private func iconButton(_ systemName: String, font: Font = .title3,
                            tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(font)
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    /// 隐藏按钮承载详情级快捷键：↑上一条 ↓下一条，⌘L 朗读 ⌘D 收藏 ⌘R 修复。
    @ViewBuilder
    private var navShortcuts: some View {
        Group {
            Button("") { go(-1) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("") { go(1) }.keyboardShortcut(.downArrow, modifiers: [])
            Button("") { Speaker.shared.speak(word.headword) }
                .keyboardShortcut("l", modifiers: .command)
            Button("") {
                word.isFavorite.toggle()
                try? modelContext.save()
            }
            .keyboardShortcut("d", modifiers: .command)
            Button("") { runRepair() }.keyboardShortcut("r", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .focusable(false)
        .accessibilityHidden(true)
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

            // ── 复习提醒（跨平台）────────────────────────────
            Section {
                Toggle(
                    String(localized: "settings.reminder.enabled", defaultValue: "每日复习提醒"),
                    isOn: $appState.reviewReminderEnabled
                )
                if appState.reviewReminderEnabled {
                    DatePicker(
                        String(localized: "settings.reminder.time", defaultValue: "提醒时间"),
                        selection: $appState.reviewReminderTime,
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text(String(localized: "settings.section.reminder", defaultValue: "提醒"))
            }

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
