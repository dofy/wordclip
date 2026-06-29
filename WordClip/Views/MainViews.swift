import SwiftUI
import SwiftData
import WordClipKit
import KeyboardShortcuts

/// macOS 侧边栏
struct SidebarView: View {
    var body: some View {
        List {
            NavigationLink(destination: WordListView()) {
                Label(String(localized: "sidebar.allwords", defaultValue: "全部单词"), systemImage: "books.vertical")
            }
            NavigationLink(destination: ReviewPlaceholderView()) {
                Label(String(localized: "sidebar.review", defaultValue: "复习"), systemImage: "checkmark.circle")
            }
            // 设置通过 ⌘, 打开独立 Settings 窗口，不在侧边栏内导航
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label(String(localized: "sidebar.settings", defaultValue: "设置"), systemImage: "gearshape")
            }
            .buttonStyle(.plain)
        }
        .navigationTitle(String(localized: "app.name", defaultValue: "WordClip"))
        .listStyle(.sidebar)
    }
}

/// 词典列表页（M1 实现查词功能，当前为骨架）
struct WordListView: View {
    @Query(sort: \WordEntry.createdAt, order: .reverse) private var words: [WordEntry]

    var body: some View {
        Group {
            if words.isEmpty {
                ContentUnavailableView(
                    String(localized: "wordlist.empty.title", defaultValue: "还没有收藏的单词"),
                    systemImage: "books.vertical",
                    description: Text(String(localized: "wordlist.empty.description",
                        defaultValue: "在任意 App 中选中单词，用快捷键一键收录"))
                )
            } else {
                List(words) { word in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(word.headword)
                            .font(.headline)
                        if let definition = word.definition {
                            Text(definition.components(separatedBy: "\n").first ?? definition)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "tab.wordlist", defaultValue: "词典"))
    }
}

/// 复习页占位（M3 实现）
struct ReviewPlaceholderView: View {
    var body: some View {
        ContentUnavailableView(
            String(localized: "review.coming.title", defaultValue: "复习功能即将上线"),
            systemImage: "checkmark.circle",
            description: Text(String(localized: "review.coming.description",
                defaultValue: "先收集一些单词，复习功能将在后续版本中推出"))
        )
        .navigationTitle(String(localized: "tab.review", defaultValue: "复习"))
    }
}

/// 设置页
struct SettingsView: View {
    @EnvironmentObject private var entitlement: MockEntitlement
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            // ── 取词 ──────────────────────────────────────
            Section {
                Toggle(
                    String(localized: "settings.capture.enabled", defaultValue: "启用全局取词"),
                    isOn: $appState.captureEnabled
                )

                KeyboardShortcuts.Recorder(
                    String(localized: "settings.capture.shortcut", defaultValue: "取词快捷键"),
                    name: .collectWord
                )
            } header: {
                Text(String(localized: "settings.section.capture", defaultValue: "取词"))
            } footer: {
                Text(String(localized: "settings.capture.hint",
                    defaultValue: "在任意 App 中选中单词，按下快捷键即可收录到 WordClip"))
                .foregroundStyle(.secondary)
            }

            // ── 通用 ──────────────────────────────────────
            Section {
                Toggle(
                    String(localized: "settings.general.launchatlogin", defaultValue: "登录时自动启动"),
                    isOn: $appState.launchAtLogin
                )
            } header: {
                Text(String(localized: "settings.section.general", defaultValue: "通用"))
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
        .frame(width: 420)
        #endif
    }
}
