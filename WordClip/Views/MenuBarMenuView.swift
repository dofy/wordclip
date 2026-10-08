#if os(macOS)
import SwiftUI
import SwiftData
import WordClipKit

/// 状态栏菜单内容
struct MenuBarMenuView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.modelContext) private var modelContext
    /// 用于打开/激活主窗口
    @Environment(\.openWindow) private var openWindow

    @State private var total = 0
    @State private var due = 0
    @State private var newWords = 0

    var body: some View {
        // 今日概览
        Text(String(localized: "menubar.overview",
                    defaultValue: "Wordbook \(total) · Due \(due) · New \(newWords)"))
            .font(.caption)

        Divider()

        // 取词开关
        Button {
            appState.captureEnabled.toggle()
        } label: {
            Label(
                appState.captureEnabled
                    ? String(localized: "menubar.capture.disable", defaultValue: "Disable Selection Capture")
                    : String(localized: "menubar.capture.enable", defaultValue: "Enable Selection Capture"),
                systemImage: appState.captureEnabled ? "scissors.badge.ellipsis" : "scissors"
            )
        }
        .keyboardShortcut("e", modifiers: [.command])

        Divider()

        // 打开主窗口
        //
        // 先试已登记的窗口：⌘W 是 orderOut 而不是真关，窗口对象还在，直接前置能保住侧边栏
        // 选中项和滚动位置。只有真被关掉过（「文件 → 关闭」）才走 openWindow 重建场景。
        Button(String(localized: "menubar.open", defaultValue: "Open WordClip")) {
            AppDelegate.openMainWindow = { openWindow(id: "main") }
            AppDelegate.showMainWindow()
        }
        .keyboardShortcut("o", modifiers: [.command])

        // 打开设置
        //
        // Dock 图标隐藏时应用菜单栏也没了，⌘, 不再生效，设置只能从这里进。
        Button(String(localized: "menu.settings", defaultValue: "Settings…")) {
            DockVisibility.shared.showDockIcon()
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: [.command])

        Divider()

        // 退出
        Button(String(localized: "menubar.quit", defaultValue: "Quit")) {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: [.command])

        // 菜单展开时刷新统计（MenuBarExtra 菜单每次打开会重建）
        Color.clear.frame(width: 0, height: 0).onAppear(perform: refreshStats)
    }

    /// 轻量统计：总数 / 到期待复习 / 新词。
    private func refreshStats() {
        let all = (try? modelContext.fetch(FetchDescriptor<WordEntry>())) ?? []
        let now = Date()
        total = all.count
        due = all.filter { $0.isDue(asOf: now) }.count
        newWords = all.filter { $0.isNew }.count
    }
}
#endif
