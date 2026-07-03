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
            Label(String(localized: "sidebar.allwords", defaultValue: "生词本"), systemImage: "books.vertical")
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

/// 单词列表排序方式（含维度与升降序）。持久化用 rawValue。
enum WordSort: String, CaseIterable, Identifiable {
    case createdDesc, createdAsc
    case alphaAsc, alphaDesc
    case familiarityDesc, familiarityAsc

    var id: String { rawValue }

    var label: String {
        switch self {
        case .createdDesc:      return String(localized: "sort.created.desc", defaultValue: "最近收录")
        case .createdAsc:       return String(localized: "sort.created.asc", defaultValue: "最早收录")
        case .alphaAsc:         return String(localized: "sort.alpha.asc", defaultValue: "字母 A→Z")
        case .alphaDesc:        return String(localized: "sort.alpha.desc", defaultValue: "字母 Z→A")
        case .familiarityDesc:  return String(localized: "sort.familiarity.desc", defaultValue: "熟悉度 高→低")
        case .familiarityAsc:   return String(localized: "sort.familiarity.asc", defaultValue: "熟悉度 低→高")
        }
    }

    /// 排序比较器：返回 lhs 是否应排在 rhs 前面。
    func areInOrder(_ a: WordEntry, _ b: WordEntry) -> Bool {
        switch self {
        case .createdDesc: return a.createdAt > b.createdAt
        case .createdAsc:  return a.createdAt < b.createdAt
        case .alphaAsc:
            return a.headword.localizedCaseInsensitiveCompare(b.headword) == .orderedAscending
        case .alphaDesc:
            return a.headword.localizedCaseInsensitiveCompare(b.headword) == .orderedDescending
        case .familiarityDesc:
            return a.familiarity != b.familiarity
                ? a.familiarity > b.familiarity
                : a.headword.localizedCaseInsensitiveCompare(b.headword) == .orderedAscending
        case .familiarityAsc:
            return a.familiarity != b.familiarity
                ? a.familiarity < b.familiarity
                : a.headword.localizedCaseInsensitiveCompare(b.headword) == .orderedAscending
        }
    }

    /// 分组：同维度的升降序放一组，菜单里用 Divider 隔开。
    static var groups: [[WordSort]] {
        [[.createdDesc, .createdAsc], [.alphaAsc, .alphaDesc], [.familiarityDesc, .familiarityAsc]]
    }
}

/// 列表选中项：生词本已收录词，或词典库未收录词。三栏共用一个选中。
enum WordSelection: Hashable {
    case word(WordEntry.ID)
    case dict(String)
}

/// 生词本页：三栏（导航→列表→详情）。单击即选中并在右侧显示详情，
/// 无弹窗、无双击、无自定义手势——单击选中/焦点由 List 原生处理。
/// iPhone（紧凑）降级为点击 push 详情。
struct WordListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query(sort: \WordEntry.createdAt, order: .reverse) private var words: [WordEntry]

    @State private var selectedItem: WordSelection?   // 三栏统一选中
    @State private var isRepairing = false
    @State private var repairMessage: String?
    @State private var pendingDelete: [WordEntry] = []  // 待确认删除
    @State private var showDeleteConfirm = false
    @State private var searchText = ""
    @State private var debouncedSearch = ""                  // 防抖后的搜索词
    @State private var showingAddWord = false
    @State private var showFavoritesOnly = false
    @AppStorage("wordlist.sort") private var sortRaw = WordSort.createdDesc.rawValue
    @State private var backfillAttempted: Set<String> = []   // 已尝试补全的 lemma
    @State private var displayWords: [WordEntry] = []        // 缓存的过滤+排序结果
    @State private var dictSuggestions: [String] = []        // 词典库里匹配但未收录的词

    private var sort: WordSort {
        get { WordSort(rawValue: sortRaw) ?? .createdDesc }
        nonmutating set { sortRaw = newValue.rawValue }
    }
    @State private var isBackfilling = false
    @FocusState private var searchFocused: Bool

    /// 需要（重新）补全释义、且本会话尚未尝试过的词：
    /// - 释义为空（收录时词典未就绪）
    /// - 或释义是旧版「前缀 fallback」的残留 artifact，如 brought → "[broughton] …"
    ///   （现已加入词形还原，重查会得到更准确的 "[bring] …"）
    private var backfillPending: [WordEntry] {
        words.filter { word in
            guard !backfillAttempted.contains(word.lemma) else { return false }
            return (word.definition?.isEmpty ?? true)
                || Self.isFallbackArtifact(word.definition)
        }
    }

    /// 释义是否为「[英文原形] …」形式的 fallback 残留。
    /// CJK 学科标记如「[计]」「[化]」内部非 ASCII 字母，不会被误判。
    static func isFallbackArtifact(_ def: String?) -> Bool {
        guard let def, def.hasPrefix("[") else { return false }
        guard let close = def.firstIndex(of: "]") else { return false }
        let inner = def[def.index(after: def.startIndex)..<close]
        return !inner.isEmpty && inner.allSatisfy { $0.isASCII && ($0.isLetter || $0 == "-") }
    }
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
    #endif

    /// 是否为宽屏（iPad 侧边栏 / macOS）——决定是否启用列表键盘导航。
    /// iPhone（compact）无外接键盘且单击即开，不需要行级快捷键与自动选中。
    private var isRegularWidth: Bool {
        #if os(iOS)
        hSizeClass == .regular
        #else
        true
        #endif
    }

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

    /// 展示用列表：缓存的过滤+排序结果。避免 body 多处引用时重复计算
    /// （大词量下方向键/刷新会重排整表，导致黏滞）。仅在输入变化时 recompute。
    private var filteredWords: [WordEntry] { displayWords }

    /// 重新计算过滤 + 排序结果（纯函数式，写入缓存）。
    private func recomputeDisplayWords() {
        var result = words
        if showFavoritesOnly {
            result = result.filter { $0.isFavorite }
        }
        let q = debouncedSearch.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            result = result.filter { word in
                word.headword.lowercased().contains(q)
                    || word.lemma.contains(q)
                    || (word.definition?.lowercased().contains(q) ?? false)
            }
        }
        displayWords = result.sorted(by: sort.areInOrder)
    }

    /// 刷新「词典库匹配但未收录」的建议：搜索非空时按前缀查词库，
    /// 剔除已在生词本里的词。空搜索时清空。
    private func refreshDictSuggestions() async {
        let q = debouncedSearch.trimmingCharacters(in: .whitespaces).lowercased()
        guard q.count >= 1, let dict = appState.dictionary else {
            dictSuggestions = []; return
        }
        let collected = Set(words.map(\.lemma))
        let hits = await dict.suggest(prefix: q, limit: 30)
        dictSuggestions = hits.filter { !collected.contains($0.lowercased()) }
    }

    /// 是否处于搜索态（有防抖后的关键词）。
    private var isSearching: Bool {
        !debouncedSearch.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        layout
        .navigationTitle(String(localized: "tab.wordlist", defaultValue: "生词本"))
        // 缓存重算：仅在数据源/过滤/排序变化时重排一次，body 其余刷新直接读缓存。
        .onAppear { recomputeDisplayWords() }
        .onChange(of: words) { _, _ in recomputeDisplayWords() }
        .onChange(of: showFavoritesOnly) { _, _ in recomputeDisplayWords() }
        .onChange(of: sortRaw) { _, _ in recomputeDisplayWords() }
        .onChange(of: debouncedSearch) { _, _ in recomputeDisplayWords() }
        // 词典建议随防抖搜索刷新（依赖词典就绪与生词本变化）。
        .task(id: "\(debouncedSearch)|\(words.count)|\(appState.dictionary != nil)") {
            await refreshDictSuggestions()
        }
        // 搜索防抖：停顿 250ms 再过滤，避免每敲一键都重排整表。
        .task(id: searchText) {
            if searchText == debouncedSearch { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            debouncedSearch = searchText
        }
        // 词典就绪后自动补全「收录时因词典未加载而漏填」的释义（静默，仅补空缺）。
        // 以「待补数 + 词典是否就绪」为 id：词条随 @Query 陆续加载时会重新触发，
        // 已尝试过的 lemma 记入 backfillAttempted，避免对词典真的没有的词反复查。
        .task(id: "\(backfillPending.count)-\(appState.dictionary != nil)") {
            await backfillIfNeeded()
        }
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: String(localized: "wordlist.search.prompt", defaultValue: "搜索单词或释义")
        )
        .searchFocused($searchFocused)
        .background(searchFocusShortcuts)
        .toolbar {
            ToolbarItemGroup {
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

                // 排序
                Menu {
                    ForEach(Array(WordSort.groups.enumerated()), id: \.offset) { idx, group in
                        ForEach(group) { option in
                            Button {
                                sort = option
                            } label: {
                                if sort == option {
                                    Label(option.label, systemImage: "checkmark")
                                } else {
                                    Text(option.label)
                                }
                            }
                        }
                        if idx < WordSort.groups.count - 1 { Divider() }
                    }
                } label: {
                    Label(String(localized: "wordlist.toolbar.sort", defaultValue: "排序"),
                          systemImage: "arrow.up.arrow.down")
                }

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
                .keyboardShortcut("n", modifiers: .command)
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
        .confirmationDialog(
            deleteConfirmTitle,
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "delete.confirm", defaultValue: "删除"), role: .destructive) {
                let deletedIDs = Set(pendingDelete.map(\.id))
                actions.delete(pendingDelete)
                // 若当前选中项被删，清空右侧详情
                if case .word(let id) = selectedItem, deletedIDs.contains(id) {
                    selectedItem = nil
                }
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
        #if os(iOS)
        // iOS/iPad：滑动/点击删除是明确手势，直接删除不再二次确认
        let deletedIDs = Set(targets.map(\.id))
        actions.delete(targets)
        if case .word(let id) = selectedItem, deletedIDs.contains(id) {
            selectedItem = nil
        }
        #else
        // macOS：⌘⌫/菜单删除，弹确认避免误删
        pendingDelete = targets
        showDeleteConfirm = true
        #endif
    }

    // MARK: - 三栏布局

    /// 宽屏（iPad/macOS）：列表 | 详情两栏；iPhone（紧凑）：单列表，点击 push 详情。
    @ViewBuilder
    private var layout: some View {
        #if os(iOS)
        if !isRegularWidth {
            // 紧凑（iPhone）：单列表，选中即 push 详情（两级导航）
            listPane
                .navigationDestination(item: $selectedItem) { sel in
                    compactDetail(for: sel)
                }
        } else {
            splitLayout
        }
        #else
        splitLayout
        #endif
    }

    #if os(iOS)
    /// iPhone push 目标：按选中类型渲染详情，铺满页面。
    @ViewBuilder
    private func compactDetail(for sel: WordSelection) -> some View {
        switch sel {
        case .word(let id):
            if let word = filteredWords.first(where: { $0.id == id }) {
                WordDetailPane(
                    words: filteredWords,
                    current: Binding(
                        get: { currentWord },
                        set: { selectedItem = $0.map { .word($0.id) } }
                    ),
                    fallback: word,
                    onRepair: { await repairOne($0) }
                )
            }
        case .dict(let term):
            DictionaryPreviewPane(term: term) {
                await appState.collect(word: term)
                if let w = words.first(where: { $0.lemma == term.lowercased() }) {
                    selectedItem = .word(w.id)
                }
            }
        }
    }
    #endif

    private var splitLayout: some View {
        HStack(spacing: 0) {
            listPane
                #if os(macOS)
                .frame(minWidth: 260, idealWidth: 320, maxWidth: 420)
                #else
                .frame(minWidth: 300, idealWidth: 360, maxWidth: 460)
                #endif
            Divider()
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 左栏：列表（生词本段 + 词典段）

    @ViewBuilder
    private var listPane: some View {
        Group {
            if words.isEmpty && !isSearching {
                ContentUnavailableView(
                    String(localized: "wordlist.empty.title", defaultValue: "还没有收藏的单词"),
                    systemImage: "books.vertical",
                    description: Text(emptyDescription)
                )
            } else if filteredWords.isEmpty && dictSuggestions.isEmpty && isSearching {
                ContentUnavailableView.search(text: searchText)
            } else {
                wordList
            }
        }
    }

    @ViewBuilder
    private var wordList: some View {
        List(selection: $selectedItem) {
            // 生词本匹配
            if !filteredWords.isEmpty {
                Section {
                    ForEach(filteredWords) { word in
                        row(for: word)
                            .tag(WordSelection.word(word.id))
                            .contextMenu { rowContextMenu(word) }
                    }
                    .onDelete { offsets in
                        requestDelete(offsets.map { filteredWords[$0] })
                    }
                } header: {
                    if isSearching {
                        Text(String(localized: "wordlist.section.mine", defaultValue: "生词本"))
                    }
                }
            }

            // 词典库匹配、未收录（搜索态才显示）
            if isSearching && !dictSuggestions.isEmpty {
                Section {
                    ForEach(dictSuggestions, id: \.self) { term in
                        dictSuggestionRow(term)
                            .tag(WordSelection.dict(term))
                    }
                } header: {
                    Text(String(localized: "wordlist.section.dict", defaultValue: "词典（未收录）"))
                }
            }
        }
        .background(isRegularWidth ? listShortcuts : nil)
        #if os(macOS)
        .onDeleteCommand {
            if case .word(let id) = selectedItem,
               let w = filteredWords.first(where: { $0.id == id }) {
                requestDelete([w])
            }
        }
        #endif
    }

    // MARK: - 右栏：详情

    @ViewBuilder
    private var detailPane: some View {
        switch selectedItem {
        case .word(let id):
            if let word = filteredWords.first(where: { $0.id == id }) {
                WordDetailPane(
                    words: filteredWords,
                    current: Binding(
                        get: { currentWord },
                        set: { selectedItem = $0.map { .word($0.id) } }
                    ),
                    fallback: word,
                    onRepair: { await repairOne($0) }
                )
                .id(id)   // 切词时重建，重置滚动/状态
            } else {
                detailPlaceholder
            }
        case .dict(let term):
            DictionaryPreviewPane(term: term) {
                await appState.collect(word: term)
                // 收录后：从词典段消失，转选中生词本里的该词
                await refreshDictSuggestions()
                if let w = words.first(where: { $0.lemma == term.lowercased() }) {
                    selectedItem = .word(w.id)
                }
            }
            .id(term)
        case .none:
            detailPlaceholder
        }
    }

    private var detailPlaceholder: some View {
        ContentUnavailableView(
            String(localized: "detail.placeholder.title", defaultValue: "选择一个单词"),
            systemImage: "sidebar.right",
            description: Text(String(localized: "detail.placeholder.desc",
                defaultValue: "从左侧选择单词查看释义，或搜索词典收录生词"))
        )
    }

    @ViewBuilder
    private func rowContextMenu(_ word: WordEntry) -> some View {
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

    /// 词典建议行：单词 + 图标（选中由 List 处理，右栏显示预览）。
    @ViewBuilder
    private func dictSuggestionRow(_ term: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "character.book.closed")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(term)
                .font(.body)
            Spacer()
        }
    }

    /// 选中某生词本词（供快捷键/程序化选中用）。
    private func open(_ word: WordEntry) {
        selectedItem = .word(word.id)
    }

    /// 词典就绪后静默补全空释义 / 重查旧 fallback 残留。仅处理尚未尝试过的词，
    /// 查过即记入 backfillAttempted，词典真的没有的词只查一次、不反复重试。
    /// 用 actions.repair（逐条覆盖）而非 repairAll（只填空），以便刷新 artifact。
    private func backfillIfNeeded() async {
        guard !isBackfilling, appState.dictionary != nil else { return }
        let pending = backfillPending
        guard !pending.isEmpty else { return }
        isBackfilling = true
        defer { isBackfilling = false }
        // 先标记，避免因仍无更优结果而下一轮又被选中
        backfillAttempted.formUnion(pending.map(\.lemma))
        for word in pending {
            _ = await actions.repair(word)
        }
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

    /// 当前选中的生词本词条（词典项返回 nil）。
    private var currentWord: WordEntry? {
        if case .word(let id) = selectedItem {
            return filteredWords.first { $0.id == id }
        }
        return nil
    }

    /// 隐藏按钮承载列表级快捷键，作用于当前选中词条。
    /// ⌘L 朗读、⌘D 收藏、⌘R 修复、⌘⌫ 删除（选中即在右栏显示，无需回车打开）。
    @ViewBuilder
    private var listShortcuts: some View {
        Group {
            Button("") {
                if let w = currentWord { Speaker.shared.speak(w.headword) }
            }
            .keyboardShortcut("l", modifiers: .command)

            Button("") {
                guard let w = currentWord else { return }
                w.isFavorite.toggle()
                try? modelContext.save()
            }
            .keyboardShortcut("d", modifiers: .command)

            Button("") {
                if let w = currentWord { Task { await repairOne(w) } }
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("") {
                if let w = currentWord { requestDelete([w]) }
            }
            .keyboardShortcut(.delete, modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .focusable(false)
        .accessibilityHidden(true)
    }

    /// 右侧复习状态小徽标：新词 / 待复习（已到期）/ 已排期。
    @ViewBuilder
    private func reviewStatusBadge(for word: WordEntry) -> some View {
        if word.repetitions == 0 && word.lastReviewedAt == nil {
            statusTag(String(localized: "wordlist.status.new", defaultValue: "新词"), color: .green)
        } else if let due = word.dueAt, due <= Date() {
            statusTag(String(localized: "wordlist.status.due", defaultValue: "待复习"), color: .orange)
        } else {
            EmptyView()
        }
    }

    private func statusTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }

    @ViewBuilder
    private func row(for word: WordEntry) -> some View {
        HStack(alignment: .center, spacing: 12) {
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

            Spacer(minLength: 8)

            // 右侧：复习状态徽标 + 熟悉度点，利用留白展示学习进度
            VStack(alignment: .trailing, spacing: 5) {
                reviewStatusBadge(for: word)
                FamiliarityBadge(familiarity: word.familiarity)
            }
            .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // 三栏布局：单击选中由 List 原生处理（右栏显示详情），无需任何自定义手势。
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

/// 单词详情（右栏内嵌）：展示完整释义、音标、来源，支持上下切换词条。
struct WordDetailPane: View {
    let words: [WordEntry]
    @Binding var current: WordEntry?
    /// 兜底：words 为空或找不到时显示的词条。
    let fallback: WordEntry
    var onRepair: (@MainActor (WordEntry) async -> Void)? = nil

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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer
            #if os(macOS)
            shortcutHint
            #endif
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(navShortcuts)
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 单词独占整行、可换行、给足空间
            Text(word.headword)
                .font(.largeTitle.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let phonetic = word.phonetic, !phonetic.isEmpty {
                Text("/\(phonetic)/")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // 操作行：朗读 / 收藏 …… 熟悉度 …… 上一条/下一条
            HStack(spacing: 14) {
                iconButton("speaker.wave.2.fill", tint: .accentColor) {
                    Speaker.shared.speak(word.headword)
                }
                iconButton(word.isFavorite ? "star.fill" : "star",
                           tint: word.isFavorite ? .yellow : .secondary) {
                    word.isFavorite.toggle()
                    try? modelContext.save()
                }
                FamiliarityBadge(familiarity: word.familiarity)
                Spacer()
                if words.count > 1 {
                    if let i = index {
                        Text("\(i + 1) / \(words.count)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    iconButton("chevron.up", tint: canPrev ? .secondary : Color.secondary.opacity(0.3)) {
                        go(-1)
                    }
                    .disabled(!canPrev)
                    iconButton("chevron.down", tint: canNext ? .secondary : Color.secondary.opacity(0.3)) {
                        go(1)
                    }
                    .disabled(!canNext)
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

/// 词典未收录词的详情预览（右栏内嵌）：查词 → 释义 + 「收录到生词本」。
struct DictionaryPreviewPane: View {
    let term: String
    let onCollect: () async -> Void

    @EnvironmentObject private var appState: AppState
    @State private var result: DictionaryResult?
    @State private var loading = true
    @State private var isCollecting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if loading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let result {
                HStack(spacing: 10) {
                    Text(result.word).font(.largeTitle.bold())
                    if let ph = result.phonetic, !ph.isEmpty {
                        Text("/\(ph)/").font(.title3).foregroundStyle(.secondary)
                    }
                    Button {
                        Speaker.shared.speak(result.word)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill").font(.title3).foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain).focusable(false)
                    Spacer()
                }
                Divider()
                ScrollView {
                    StructuredDefinitionView(definition: result.definition, definitionEn: result.definitionEn)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                Button {
                    Task { isCollecting = true; await onCollect(); isCollecting = false }
                } label: {
                    if isCollecting {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(String(localized: "lookup.collect", defaultValue: "收录到生词本"),
                              systemImage: "plus.circle.fill")
                            .font(.body.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCollecting)
                .keyboardShortcut(.return, modifiers: .command)
            } else {
                ContentUnavailableView(
                    String(localized: "lookup.notfound.title", defaultValue: "未找到释义"),
                    systemImage: "questionmark.circle",
                    description: Text(term)
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: term) {
            loading = true
            result = await appState.dictionary?.lookup(term)
            loading = false
        }
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
    @State private var ocrShortcut: KeyboardShortcuts.Shortcut? = KeyboardShortcuts.getShortcut(for: .collectWordOCR)
    #endif

    // 备份导出/导入
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var exportDocument: WordBackupDocument?
    @State private var backupMessage: String?

    // 付费墙
    @State private var showingPaywall = false

    // iCloud 同步（先预留 UI，功能待付费开发者账号）
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false

    private var backup: BackupService {
        BackupService(modelContext: modelContext)
    }

    var body: some View {
        Form {
            #if os(macOS)
            // ── 取词（仅 macOS）──────────────────────────────
            Section {
                Toggle(
                    String(localized: "settings.capture.enabled", defaultValue: "启用全局收词"),
                    isOn: $appState.captureEnabled
                )

                LabeledContent(String(localized: "settings.capture.shortcut", defaultValue: "收词快捷键")) {
                    ShortcutRecorderField(shortcut: $collectShortcut)
                }
                .onChange(of: collectShortcut) { _, newValue in
                    KeyboardShortcuts.setShortcut(newValue, for: .collectWord)
                    appState.refreshHotkeyRegistration()
                }

                // OCR 取词快捷键（Pro）：免费用户显示锁，点击弹付费墙
                if entitlement.isPro {
                    LabeledContent(String(localized: "settings.capture.ocr.shortcut",
                                          defaultValue: "OCR 收词快捷键")) {
                        ShortcutRecorderField(shortcut: $ocrShortcut)
                    }
                    .onChange(of: ocrShortcut) { _, newValue in
                        KeyboardShortcuts.setShortcut(newValue, for: .collectWordOCR)
                        appState.refreshHotkeyRegistration()
                    }
                } else {
                    Button {
                        showingPaywall = true
                    } label: {
                        HStack {
                            Label(String(localized: "settings.capture.ocr.shortcut",
                                        defaultValue: "OCR 收词快捷键"),
                                  systemImage: "text.viewfinder")
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(String(localized: "settings.section.capture", defaultValue: "收词"))
            } footer: {
                Text(String(localized: "settings.capture.hint",
                    defaultValue: "在任意 App 中选中单词，按下快捷键即可收录到 WordClip。OCR 收词（Pro）可框选屏幕区域识别其中的英文单词。"))
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

            // ── 词典（内置 + 导入）──────────────────────────
            DictionarySettingsSection()
                .environmentObject(appState)

            // ── 账户 ──────────────────────────────────────
            Section {
                LabeledContent(
                    String(localized: "settings.plan", defaultValue: "当前方案"),
                    value: entitlement.isPro
                        ? String(localized: "settings.plan.pro", defaultValue: "Pro（终身）")
                        : String(localized: "settings.plan.free", defaultValue: "免费版")
                )
                if !entitlement.isPro {
                    Button {
                        showingPaywall = true
                    } label: {
                        Label(String(localized: "settings.upgrade", defaultValue: "升级 WordClip Pro"),
                              systemImage: "sparkles")
                    }
                }
            } header: {
                Text(String(localized: "settings.account", defaultValue: "账户"))
            } footer: {
                if !entitlement.isPro {
                    Text(String(localized: "settings.account.hint",
                        defaultValue: "一次性购买，终身解锁 OCR 收词、iCloud 同步与导入/导出功能。"))
                    .foregroundStyle(.secondary)
                }
            }

            // ── iCloud 同步（预留 UI，功能待开发者账号）──────────
            Section {
                Toggle(isOn: $iCloudSyncEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "settings.icloud.toggle", defaultValue: "iCloud 同步"))
                        Text(String(localized: "settings.icloud.soon", defaultValue: "即将推出"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(true)   // 预留 UI：真实同步待 CloudKit + 付费账号
            } header: {
                Text(String(localized: "settings.section.icloud", defaultValue: "同步"))
            } footer: {
                Text(String(localized: "settings.icloud.hint",
                    defaultValue: "Pro 功能：词典与学习进度跨设备自动同步。开发中，敬请期待。"))
                .foregroundStyle(.secondary)
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
                    if entitlement.isPro {
                        showingImporter = true
                    } else {
                        showingPaywall = true
                    }
                } label: {
                    HStack {
                        Label(String(localized: "settings.import", defaultValue: "导入词库"),
                              systemImage: "square.and.arrow.down")
                        if !entitlement.isPro {
                            Spacer()
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text(String(localized: "settings.section.data", defaultValue: "数据"))
            } footer: {
                Text(entitlement.isPro
                    ? String(localized: "settings.data.hint",
                        defaultValue: "导出为 JSON 文件备份，或在新设备导入。导入按单词智能合并，不会覆盖已有的学习进度。")
                    : String(localized: "settings.data.hint.free",
                        defaultValue: "免费版可导出备份；导入为 Pro 功能。导入按单词智能合并，不会覆盖已有的学习进度。"))
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
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
                .environmentObject(entitlement)
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
