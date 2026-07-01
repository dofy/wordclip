import SwiftUI

/// 侧边栏导航目标
enum SidebarItem: Hashable, CaseIterable {
    case allWords
    case review
    case stats
    case settings
}

/// 顶层导航容器。
/// - macOS / iPad（regular 宽度）：NavigationSplitView 侧边栏 + 详情
/// - iPhone（compact 宽度）：底部 TabView
struct ContentView: View {

    @EnvironmentObject private var appState: AppState

    @State private var selection: SidebarItem? = .allWords

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
    #endif

    var body: some View {
        content
            #if os(macOS)
            .safeAreaInset(edge: .top, spacing: 0) {
                if appState.needsAccessibilityPrompt {
                    AccessibilityBanner()
                }
            }
            .onAppear {
                // 启动时就检测权限，不等用户按快捷键才发现
                appState.checkAccessibilityStatus()
            }
            #endif
            .overlay(alignment: .top) {
                if let message = appState.lastCollectMessage {
                    Text(message)
                        .font(.callout)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(radius: 4, y: 2)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: appState.lastCollectMessage)
    }

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        splitView
        #else
        // iPad（regular）用侧边栏，iPhone（compact）用 TabView
        if hSizeClass == .regular {
            splitView
        } else {
            tabView
        }
        #endif
    }

    // MARK: - 侧边栏 + 详情（macOS / iPad）

    @ViewBuilder
    private var splitView: some View {
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            NavigationStack {
                detailView(for: selection ?? .allWords)
            }
        }
        .background(sidebarShortcuts)
    }

    /// ⌘1–⌘4 快速切换侧边栏项目。隐藏按钮承载快捷键。
    @ViewBuilder
    private var sidebarShortcuts: some View {
        Group {
            ForEach(Array(SidebarItem.allCases.enumerated()), id: \.offset) { idx, item in
                Button("") { selection = item }
                    .keyboardShortcut(KeyEquivalent(Character("\(idx + 1)")), modifiers: .command)
            }
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func detailView(for item: SidebarItem) -> some View {
        switch item {
        case .allWords: WordListView()
        case .review: StudyView()
        case .stats: StatsView()
        case .settings: SettingsView()
        }
    }

    // MARK: - 底部标签栏（iPhone）

    @ViewBuilder
    private var tabView: some View {
        TabView {
            NavigationStack { WordListView() }
                .tabItem {
                    Label(String(localized: "tab.wordlist", defaultValue: "词典"), systemImage: "books.vertical")
                }
            NavigationStack { StudyView() }
                .tabItem {
                    Label(String(localized: "tab.review", defaultValue: "复习"), systemImage: "checkmark.circle")
                }
            NavigationStack { StatsView() }
                .tabItem {
                    Label(String(localized: "tab.stats", defaultValue: "统计"), systemImage: "chart.xyaxis.line")
                }
            NavigationStack { SettingsView() }
                .tabItem {
                    Label(String(localized: "tab.settings", defaultValue: "设置"), systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
}
