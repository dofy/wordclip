import SwiftUI

/// 侧边栏导航目标
enum SidebarItem: Hashable {
    case allWords
    case review
    case stats
    case settings
}

/// 顶层导航容器。macOS 用 NavigationSplitView，iOS 用 TabView。
struct ContentView: View {

    @EnvironmentObject private var appState: AppState

    #if os(macOS)
    @State private var selection: SidebarItem? = .allWords
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
        NavigationSplitView {
            SidebarView(selection: $selection)
        } detail: {
            switch selection ?? .allWords {
            case .allWords: WordListView()
            case .review: StudyView()
            case .stats: StatsView()
            case .settings: SettingsView()
            }
        }
        #else
        TabView {
            NavigationStack {
                WordListView()
            }
            .tabItem {
                Label(String(localized: "tab.wordlist", defaultValue: "词典"), systemImage: "books.vertical")
            }

            NavigationStack {
                StudyView()
            }
            .tabItem {
                Label(String(localized: "tab.review", defaultValue: "复习"), systemImage: "checkmark.circle")
            }

            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label(String(localized: "tab.stats", defaultValue: "统计"), systemImage: "chart.xyaxis.line")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(String(localized: "tab.settings", defaultValue: "设置"), systemImage: "gearshape")
            }
        }
        #endif
    }
}

#Preview {
    ContentView()
}
