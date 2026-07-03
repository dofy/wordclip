#if os(macOS)
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// 收词快捷键：默认 ⌥⌘C，用户可在设置中修改
    static let collectWord = Self("collectWord", initial: .init(.c, modifiers: [.option, .command]))

    /// OCR 取词快捷键：默认 ⌥⌘O，框选屏幕区域识别单词（Pro）
    static let collectWordOCR = Self("collectWordOCR", initial: .init(.o, modifiers: [.option, .command]))
}
#endif

