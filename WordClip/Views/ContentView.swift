import SwiftUI

/// 顶层导航容器。macOS 用 NavigationSplitView，iOS 用 TabView。
struct ContentView: View {

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            SidebarView()
        } detail: {
            WordListView()
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
                ReviewPlaceholderView()
            }
            .tabItem {
                Label(String(localized: "tab.review", defaultValue: "复习"), systemImage: "checkmark.circle")
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
