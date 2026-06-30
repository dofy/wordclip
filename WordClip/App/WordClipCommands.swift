#if os(macOS)
import SwiftUI

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
    }
}
#endif
