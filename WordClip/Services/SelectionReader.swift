#if os(macOS)
import AppKit
import ApplicationServices

/// 通过 Accessibility API 直接读取当前聚焦元素中选中的文本。
///
/// 相比模拟 ⌘C，这种方式不污染剪贴板、不合成按键，更直接。
/// 需要用户在「系统设置 → 隐私与安全性 → 辅助功能」中授权本 App。
enum SelectionReader {

    /// 当前是否已获得辅助功能授权。
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// 打开「辅助功能」系统设置面板。
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 读取当前系统焦点元素中选中的文本。
    /// - Returns: 选中文本；未授权、无焦点元素或无选中内容时返回 nil。
    static func selectedText() -> String? {
        guard isTrusted else { return nil }

        let systemWide = AXUIElementCreateSystemWide()

        // 取当前聚焦的 UI 元素
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused
        else { return nil }

        let axElement = element as! AXUIElement

        // 优先读 AXSelectedText
        if let text = copyStringAttribute(axElement, kAXSelectedTextAttribute) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }

        // 兜底：用选中范围从全文里截取
        if let range = copySelectedRange(axElement),
           let full = copyStringAttribute(axElement, kAXValueAttribute) {
            let ns = full as NSString
            if range.location != NSNotFound,
               range.length > 0,
               range.location + range.length <= ns.length {
                let sub = ns.substring(with: range)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !sub.isEmpty { return sub }
            }
        }

        return nil
    }

    // MARK: - Private

    private static func copyStringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    private static func copySelectedRange(_ element: AXUIElement) -> NSRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let axValue = value
        else { return nil }

        var range = CFRange()
        guard AXValueGetValue(axValue as! AXValue, .cfRange, &range) else { return nil }
        return NSRange(location: range.location, length: range.length)
    }
}
#endif
