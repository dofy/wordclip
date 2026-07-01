#if os(macOS)
import SwiftUI

// Notification.Name 定义见 ContentView.swift（跨平台共用）。

/// macOS 菜单栏命令
struct WordClipCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // ⌘, 打开设置窗口
        CommandGroup(replacing: .appSettings) {
            Button(String(localized: "menu.settings", defaultValue: "设置…")) {
                openWindow(id: "settings")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        // 独立「词典」菜单（始终渲染，⌘⇧F 才能可靠注册）。
        // 不放 File 菜单：App 层 replacing:.newItem 清空后 File 菜单不渲染，
        // after:.newItem 的项与其快捷键都不会生效。
        CommandMenu(String(localized: "menu.dictionary", defaultValue: "词典")) {
            Button(String(localized: "menu.lookup", defaultValue: "查词典…")) {
                NotificationCenter.default.post(name: .showDictionaryLookup, object: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
        }

        // 帮助 → 键盘快捷键（⌘/）
        CommandGroup(replacing: .help) {
            Button(String(localized: "shortcuts.title", defaultValue: "键盘快捷键")) {
                NotificationCenter.default.post(name: .showShortcutCheatSheet, object: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("/", modifiers: .command)
        }
    }
}
#endif
