import SwiftUI
import UniformTypeIdentifiers

/// 设置页「词典」分区：展示内置词库、导入/管理用户词库。
struct DictionarySettingsSection: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var store = DictionaryStore.shared

    @State private var showingImporter = false
    @State private var importing = false
    @State private var message: String?

    /// 允许导入的类型：CSV / 纯文本 / SQLite（用扩展名兜底 sqlite）。
    private var allowedTypes: [UTType] {
        var types: [UTType] = [.commaSeparatedText, .plainText, .text]
        if let sqlite = UTType(filenameExtension: "sqlite") { types.append(sqlite) }
        if let db = UTType(filenameExtension: "db") { types.append(db) }
        return types
    }

    var body: some View {
        Section {
            // 内置词库（固定第一项）
            LabeledContent {
                Text(String(localized: "dict.builtin.badge", defaultValue: "内置"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } label: {
                Label(String(localized: "dict.builtin.name", defaultValue: "英汉词典（ECDICT）"),
                      systemImage: "book.closed")
            }

            // 用户导入的词库
            ForEach(store.installed) { dict in
                Toggle(isOn: Binding(
                    get: { dict.enabled },
                    set: { store.setEnabled(dict, $0); appState.rebuildDictionary() }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dict.name)
                        Text(String(localized: "dict.wordcount",
                                    defaultValue: "\(dict.wordCount) 词"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        store.remove(dict)
                        appState.rebuildDictionary()
                    } label: {
                        Label(String(localized: "dict.delete", defaultValue: "删除"),
                              systemImage: "trash")
                    }
                }
                #if os(macOS)
                .contextMenu {
                    Button(role: .destructive) {
                        store.remove(dict)
                        appState.rebuildDictionary()
                    } label: {
                        Label(String(localized: "dict.delete", defaultValue: "删除"),
                              systemImage: "trash")
                    }
                }
                #endif
            }

            // 导入按钮
            Button {
                showingImporter = true
            } label: {
                if importing {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(String(localized: "dict.importing", defaultValue: "导入中…"))
                    }
                } else {
                    Label(String(localized: "dict.import", defaultValue: "导入词典…"),
                          systemImage: "plus")
                }
            }
            .disabled(importing)
        } header: {
            Text(String(localized: "settings.section.dict", defaultValue: "词典"))
        } footer: {
            Text(String(localized: "settings.dict.hint",
                defaultValue: "支持 CSV（word,释义[,音标]）与 ECDICT 结构的 SQLite。多本词典按顺序叠加查询，内置优先。"))
            .foregroundStyle(.secondary)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await runImport(url) }
        }
        .overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(.callout)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 4, y: 2)
                    .padding(.bottom, 16)
            }
        }
        .animation(.spring(duration: 0.3), value: message)
    }

    private func runImport(_ url: URL) async {
        importing = true
        defer { importing = false }
        do {
            try await store.importDictionary(from: url)
            appState.rebuildDictionary()
            flash(String(localized: "dict.import.ok", defaultValue: "已导入词典"))
        } catch {
            flash(String(localized: "dict.import.fail",
                         defaultValue: "导入失败：\(error.localizedDescription)"))
        }
    }

    private func flash(_ msg: String) {
        message = msg
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if message == msg { message = nil }
        }
    }
}
