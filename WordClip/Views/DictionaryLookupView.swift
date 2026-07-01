import SwiftUI
import WordClipKit

/// 查词面板：搜索整个词库（5 万词，只读），查看释义，并可一键收录到生词本。
/// 与「生词本」（个人收录列表）区分——这里是查询工具。
struct DictionaryLookupView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var debounced = ""
    @State private var suggestions: [String] = []
    @State private var selected: DictionaryResult?
    @State private var isCollecting = false
    @State private var toast: String?
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 420, minHeight: 400)
        #if os(macOS)
        .frame(width: 460, height: 520)
        #else
        .presentationDetents([.large])
        #endif
        .overlay(alignment: .bottom) { toastView }
        .animation(.spring(duration: 0.3), value: toast)
        .task(id: query) {
            if query == debounced { return }
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            debounced = query
        }
        .task(id: debounced) { await refreshSuggestions() }
        .onAppear { searchFocused = true }
    }

    // MARK: 头部（搜索框 + 关闭）

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(
                String(localized: "lookup.prompt", defaultValue: "查词典（全部词库）"),
                text: $query
            )
            .textFieldStyle(.plain)
            .font(.title3)
            .focused($searchFocused)
            .onSubmit { Task { await lookupExact() } }
            #if os(iOS)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            #endif
            if !query.isEmpty {
                Button {
                    query = ""; selected = nil; searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            Button {
                dismiss()
            } label: {
                Text(String(localized: "lookup.close", defaultValue: "关闭"))
            }
            .keyboardShortcut(.cancelAction)
            .focusable(false)
        }
        .padding(16)
    }

    // MARK: 内容（释义 / 建议 / 空态）

    @ViewBuilder
    private var content: some View {
        if let result = selected {
            definitionPane(result)
        } else if debounced.isEmpty {
            emptyState
        } else if suggestions.isEmpty {
            ContentUnavailableView.search(text: debounced)
        } else {
            suggestionList
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            String(localized: "lookup.empty.title", defaultValue: "查询词库"),
            systemImage: "character.book.closed",
            description: Text(String(localized: "lookup.empty.desc",
                defaultValue: "输入英文单词，查看释义并可收录到生词本"))
        )
    }

    private var suggestionList: some View {
        List(suggestions, id: \.self) { word in
            Button {
                Task { await select(word) }
            } label: {
                HStack {
                    Text(word).font(.body)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func definitionPane(_ result: DictionaryResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Button {
                    selected = nil; searchFocused = true
                } label: {
                    Image(systemName: "chevron.left").font(.body)
                }
                .buttonStyle(.plain)
                .focusable(false)

                Text(result.word).font(.title.bold())
                if let ph = result.phonetic, !ph.isEmpty {
                    Text("/\(ph)/").font(.title3).foregroundStyle(.secondary)
                }
                Button {
                    Speaker.shared.speak(result.word)
                } label: {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(.tint)
                }
                .buttonStyle(.plain)
                .focusable(false)
                Spacer()
            }

            ScrollView {
                StructuredDefinitionView(
                    definition: result.definition,
                    definitionEn: result.definitionEn
                )
            }

            Divider()
            Button {
                Task { await collect(result.word) }
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
        }
        .padding(16)
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.callout)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(radius: 4, y: 2)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: 数据

    private func refreshSuggestions() async {
        guard let dict = appState.dictionary else { suggestions = []; return }
        let q = debounced.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { suggestions = []; return }
        suggestions = await dict.suggest(prefix: q, limit: 40)
    }

    private func select(_ word: String) async {
        guard let dict = appState.dictionary else { return }
        selected = await dict.lookup(word)
    }

    /// 回车：直接查当前输入的精确词（查不到再退回建议）。
    private func lookupExact() async {
        guard let dict = appState.dictionary else { return }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        if let r = await dict.lookup(q) { selected = r }
    }

    private func collect(_ word: String) async {
        isCollecting = true
        defer { isCollecting = false }
        _ = await appState.collect(word: word)
        flash(String(localized: "lookup.collected", defaultValue: "已收录：\(word)"))
    }

    private func flash(_ msg: String) {
        toast = msg
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if toast == msg { toast = nil }
        }
    }
}
