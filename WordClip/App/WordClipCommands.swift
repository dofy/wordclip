import SwiftUI

/// macOS 菜单栏命令（全局快捷键入口将在 M2 实现）
struct WordClipCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .newItem) {
            // M2 实现：收集选中单词的菜单项
            // Button(String(localized: "Collect Selected Word")) { ... }
            //     .keyboardShortcut("w", modifiers: [.command, .shift])
        }
    }
}
