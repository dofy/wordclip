import SwiftUI

/// macOS 侧边栏
struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            Label(String(localized: "sidebar.allwords", defaultValue: "Wordbook"), systemImage: "books.vertical")
                .tag(SidebarItem.allWords)
            Label(String(localized: "sidebar.review", defaultValue: "Review"), systemImage: "checkmark.circle")
                .tag(SidebarItem.review)
            Label(String(localized: "sidebar.stats", defaultValue: "Stats"), systemImage: "chart.xyaxis.line")
                .tag(SidebarItem.stats)
        }
        .navigationTitle(String(localized: "app.name", defaultValue: "WordClip"))
        .listStyle(.sidebar)
    }
}
