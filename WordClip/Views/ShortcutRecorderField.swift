#if os(macOS)
import SwiftUI
import AppKit
import Carbon.HIToolbox
import KeyboardShortcuts

/// 自绘快捷键录制控件。
///
/// 不依赖 KeyboardShortcuts 库的 `Recorder`（其底层是可编辑 NSSearchField，
/// 在 macOS 26+ 上存在“录制后仍可输入普通字符”等问题）。这里用一个纯按钮，
/// 点击后进入录制态、用本地事件监听捕获一次组合键，绕开文本框的所有副作用。
/// 仍复用库的 `Shortcut` 类型与全局热键引擎。
struct ShortcutRecorderField: View {
    @Binding var shortcut: KeyboardShortcuts.Shortcut?

    @State private var isRecording = false

    var body: some View {
        Button(action: toggleRecording) {
            Text(label)
                .frame(minWidth: 90)
                .monospaced()
        }
        .buttonStyle(.bordered)
        .overlay(alignment: .trailing) {
            if shortcut != nil && !isRecording {
                Button {
                    shortcut = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 4)
            }
        }
        .background(KeyCaptureView(isRecording: $isRecording, onCapture: handleCapture))
    }

    private var label: String {
        if isRecording {
            return String(localized: "recorder.press", defaultValue: "按下快捷键…")
        }
        if let shortcut {
            return shortcut.description
        }
        return String(localized: "recorder.empty", defaultValue: "点击录制")
    }

    private func toggleRecording() {
        isRecording.toggle()
    }

    /// 处理捕获到的事件，返回 true 表示已消费（停止录制）。
    private func handleCapture(_ event: NSEvent) -> Bool {
        // 仅保留设备无关的修饰键标志（⌘⌥⌃⇧）
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Esc 取消
        if mods.isEmpty, event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            return true
        }
        // Delete/Backspace 清除
        if mods.isEmpty,
           event.specialKey == .delete || event.specialKey == .deleteForward || event.specialKey == .backspace {
            shortcut = nil
            isRecording = false
            return true
        }

        guard let candidate = KeyboardShortcuts.Shortcut(event: event) else {
            NSSound.beep()
            return false
        }

        // macOS 15+ 沙盒限制：Option 必须与 Command 或 Control 组合
        let hasCommandOrControl = mods.contains(.command) || mods.contains(.control)
        if mods.contains(.option), !hasCommandOrControl {
            NSSound.beep()
            return false
        }
        // 至少要有一个非 shift 修饰键
        guard !mods.subtracting(.shift).isEmpty else {
            NSSound.beep()
            return false
        }

        shortcut = candidate
        isRecording = false
        return true
    }
}

/// 用 NSView 承载本地按键监听。只有处于录制态时才拦截事件。
private struct KeyCaptureView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onCapture: (NSEvent) -> Bool

    func makeNSView(context: Context) -> CaptureNSView {
        let view = CaptureNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: CaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        if isRecording {
            nsView.startMonitoring()
        } else {
            nsView.stopMonitoring()
        }
    }

    final class CaptureNSView: NSView {
        var onCapture: ((NSEvent) -> Bool)?
        private var monitor: (any NSObjectProtocol)?

        func startMonitoring() {
            guard monitor == nil else { return }
            // 录制期间整体禁用全局热键，避免按键被已注册的快捷键吞掉
            KeyboardShortcuts.isEnabled = false
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self, let onCapture = self.onCapture else { return event }
                // handleCapture 内部会在成功/取消时把 isRecording 置回 false，
                // 进而触发 updateNSView 调 stopMonitoring 清理本监听。
                _ = onCapture(event)
                return nil // 始终吞掉事件，杜绝普通字符进入其他控件
            } as? (any NSObjectProtocol)
        }

        func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
                KeyboardShortcuts.isEnabled = true
            }
        }

        // view 离开窗口（如关闭设置）时兜底清理，避免监听泄漏
        override func viewWillMove(toWindow newWindow: NSWindow?) {
            if newWindow == nil {
                stopMonitoring()
            }
            super.viewWillMove(toWindow: newWindow)
        }
    }
}
#endif
