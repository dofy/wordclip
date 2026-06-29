import SwiftUI
import SwiftData

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
            NavigationLink(destination: SettingsView()) {
                Label(String(localized: "sidebar.settings", defaultValue: "设置"), systemImage: "gearshape")
            }
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

/// 设置页占位
struct SettingsView: View {
    @EnvironmentObject private var entitlement: MockEntitlement

    var body: some View {
        Form {
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
        #endif
    }
}
