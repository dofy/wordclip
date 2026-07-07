import SwiftUI
import SwiftData
import WordClipKit

extension Notification.Name {
    /// 请求显示键盘快捷键速查表。
    static let showShortcutCheatSheet = Notification.Name("showShortcutCheatSheet")
    /// 请求显示使用帮助面板。
    static let showHelp = Notification.Name("showHelp")
    /// 从状态栏菜单请求开始复习。
    static let startReviewFromMenuBar = Notification.Name("startReviewFromMenuBar")
    /// 请求打开词包浏览(长驻入口)。
    static let showWordPacks = Notification.Name("showWordPacks")
    /// 请求显示「导入词典」说明页。
    static let showDictionaryImportGuide = Notification.Name("showDictionaryImportGuide")
}

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
    @EnvironmentObject private var entitlement: MockEntitlement

    @State private var selection: SidebarItem? = .allWords
    @State private var showingShortcuts = false
    @State private var showingHelp = false
    @State private var showingWordPacks = false
    @State private var showingDictImportGuide = false

    // 首启词包引导：库为空且未展示过时弹出。
    @AppStorage("packs.onboarded") private var packsOnboarded = false
    @State private var showOnboarding = false
    @Query private var allWords: [WordEntry]

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
            // OCR 免费用户闸门：快捷键在视图外触发，经 AppState 标志弹付费墙
            .sheet(isPresented: $appState.showingOCRPaywall) {
                PaywallView()
                    .environmentObject(entitlement)
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
            #if os(iOS)
            // iPad：隐藏按钮承载 ⌘/；macOS 走「帮助」菜单命令（见 WordClipCommands）
            .background(
                Button("") { showingShortcuts.toggle() }
                    .keyboardShortcut("/", modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            )
            #else
            .onReceive(NotificationCenter.default.publisher(for: .showShortcutCheatSheet)) { _ in
                showingShortcuts = true
            }
            #endif
            .sheet(isPresented: $showingShortcuts) {
                ShortcutCheatSheet()
            }
            .sheet(isPresented: $showingHelp) {
                HelpView()
            }
            .sheet(isPresented: $showingDictImportGuide) {
                DictionaryImportGuideView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showDictionaryImportGuide)) { _ in
                showingDictImportGuide = true
            }
            // 长驻词包入口:菜单栏 / 复习页工具栏均经此通知唤出,补导入未导入的包。
            .sheet(isPresented: $showingWordPacks) {
                WordPackBrowserView(isOnboarding: false) {
                    showingWordPacks = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showWordPacks)) { _ in
                showingWordPacks = true
            }
            // 首启词包引导：库为空且未展示过时弹出，展示后记录标志避免重复。
            .task {
                if allWords.isEmpty && !packsOnboarded {
                    showOnboarding = true
                }
            }
            .sheet(isPresented: $showOnboarding) {
                WordPackBrowserView(isOnboarding: true) {
                    packsOnboarded = true
                    showOnboarding = false
                }
                // 禁止滑动关闭：只能经「跳过」/「导入」退出，两者都会置 packsOnboarded，
                // 避免 iOS 上滑动 dismiss 后标志未置、下次空库启动重复弹出。
                .interactiveDismissDisabled()
            }
            // 使用帮助：菜单 / 设置页 / 复习页均经此通知唤出（两端统一）
            .onReceive(NotificationCenter.default.publisher(for: .showHelp)) { _ in
                showingHelp = true
            }
            // 状态栏「开始复习」：切到复习页（StudyView 自身监听同一通知开始）
            .onReceive(NotificationCenter.default.publisher(for: .startReviewFromMenuBar)) { _ in
                selection = .review
            }
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
                    Label(String(localized: "tab.wordlist", defaultValue: "生词本"), systemImage: "books.vertical")
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
