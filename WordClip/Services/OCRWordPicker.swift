#if os(macOS)
import AppKit
import SwiftUI

/// OCR 选词面板的呈现器：用独立浮动 NSPanel 承载 `OCRWordPickerView`。
///
/// 用独立窗口而非主窗口 sheet——OCR 截屏时主窗口通常在后台，
/// 独立浮动面板可在任意 App 上方居中呈现。
@MainActor
final class OCRWordPicker {
    static let shared = OCRWordPicker()
    private init() {}

    private var panel: NSPanel?

    /// 面板固定尺寸（与 OCRWordPickerView 的 .frame 一致）。
    private static let panelSize = NSSize(width: 380, height: 380)

    /// 呈现选词面板。用户确认后回调选中的单词；取消则不回调。
    func present(words: [String], onConfirm: @escaping ([String]) -> Void) {
        dismiss()

        let view = OCRWordPickerView(
            words: words,
            onConfirm: { [weak self] picked in
                self?.dismiss()
                if !picked.isEmpty { onConfirm(picked) }
            },
            onCancel: { [weak self] in self?.dismiss() }
        )

        let hosting = NSHostingView(rootView: view)
        let size = Self.panelSize

        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false   // 我们自己持有并 orderOut，避免关闭即释放
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting
        panel.setContentSize(size)
        centerOnActiveScreen(panel, size: size)

        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func dismiss() {
        panel?.orderOut(nil)
        panel = nil
    }

    private func centerOnActiveScreen(_ panel: NSPanel, size: NSSize) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let x = frame.midX - size.width / 2
        let y = frame.midY - size.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
#endif
