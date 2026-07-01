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
                    defaultValue: "生词本 \(total) · 待复习 \(due) · 新词 \(newWords)"))
            .font(.caption)

        // 开始复习（有到期或新词时）
        Button {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .startReviewFromMenuBar, object: nil)
        } label: {
            Label(String(localized: "menubar.review", defaultValue: "开始复习"),
                  systemImage: "play.fill")
        }
        .keyboardShortcut("r", modifiers: [.command])
        .disabled(due == 0 && newWords == 0)

        Divider()

        // 取词开关
        Button {
            appState.captureEnabled.toggle()
        } label: {
            Label(
                appState.captureEnabled
                    ? String(localized: "menubar.capture.disable", defaultValue: "停用取词")
                    : String(localized: "menubar.capture.enable", defaultValue: "启用取词"),
                systemImage: appState.captureEnabled ? "scissors.badge.ellipsis" : "scissors"
            )
        }
        .keyboardShortcut("e", modifiers: [.command])

        Divider()

        // 打开主窗口
        Button(String(localized: "menubar.open", defaultValue: "打开 WordClip")) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut("o", modifiers: [.command])

        // 打开设置
        Button(String(localized: "menubar.settings", defaultValue: "设置…")) {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        // 退出
        Button(String(localized: "menubar.quit", defaultValue: "退出")) {
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
        due = all.filter { ($0.dueAt ?? .distantPast) <= now && $0.familiarity > 0 }.count
        newWords = all.filter { $0.familiarity == 0 }.count
    }
}
#endif
