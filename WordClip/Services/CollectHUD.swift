#if os(macOS)
import AppKit
import SwiftUI

/// 收词悬浮 HUD：无边框浮层，短暂显示在任意 App 上方后淡出。
/// 取代系统通知——不进通知中心、无需权限、无声音，适合高频收词反馈。
@MainActor
final class CollectHUD {
    static let shared = CollectHUD()
    private init() {}

    private var panel: NSPanel?
    /// 停留计时：到点后开始淡出。
    private var dismissTask: Task<Void, Never>?
    /// 淡出 + 收起面板。和 dismissTask 分开，这样一次新的 show 能各自取消。
    private var fadeTask: Task<Void, Never>?

    private static let fadeInDuration = 0.18
    private static let fadeOutDuration = 0.25

    /// 显示一条 HUD。
    /// - Parameters:
    ///   - symbol: SF Symbol 名
    ///   - tint: 图标色
    ///   - title: 主标题（通常是单词）
    ///   - subtitle: 副标题（释义首行 / 提示），可空
    ///   - duration: 停留秒数
    func show(symbol: String, tint: Color, title: String, subtitle: String?, duration: Double = 1.3) {
        dismissTask?.cancel()
        // 上一条还在淡出时也要拦住它：否则它的收尾会在这条显示期间把面板收走。
        fadeTask?.cancel()

        let content = HUDContent(symbol: symbol, tint: tint, title: title, subtitle: subtitle)
        let hosting = NSHostingView(rootView: content)
        hosting.layout()
        let size = hosting.fittingSize

        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.contentView = hosting
        panel.setContentSize(size)
        positionPanel(panel, size: size)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Self.fadeInDuration
            panel.animator().alphaValue = 1
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    /// 淡出并把面板收下屏。
    ///
    /// 收起动作不挂在 `NSAnimationContext` 的 completionHandler 上。实测面板会停在
    /// alpha 0 却仍留在屏幕上——`CGWindowList` 里还看得到一个 layer 25、alpha 0.00 的
    /// 窗口，说明那个回调并不保证触发。面板全透明又 `ignoresMouseEvents`,所以肉眼看不
    /// 出来,但它会一直占着一个在屏窗口。
    ///
    /// 改成自己等一段与动画等长的时间再 `orderOut`,动画只管动画。这个等待挂在
    /// `fadeTask` 上,新的 `show` 一取消它,收起就不会在新 HUD 显示期间发生。
    private func hide() {
        guard let panel else { return }

        // 动画留在同步上下文里发起。在 async 上下文里 `runAnimationGroup` 会解析到
        // async 重载（error: expression is 'async' but is not marked with 'await'），
        // 而那个重载等的正是这里不信任的那个完成回调。
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = Self.fadeOutDuration
            panel.animator().alphaValue = 0
        }

        fadeTask?.cancel()
        fadeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.fadeOutDuration))
            guard !Task.isCancelled else { return }
            panel.orderOut(nil)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        // 跨所有桌面空间 + 覆盖全屏 App
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }

    /// 定位到当前活跃屏幕的底部居中偏上。
    private func positionPanel(_ panel: NSPanel, size: NSSize) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else { return }
        let x = frame.midX - size.width / 2
        let y = frame.minY + frame.height * 0.14
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// HUD 内容视图。
private struct HUDContent: View {
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: 420)
        .fixedSize()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        )
        .padding(6)   // 给阴影留边
    }
}
#endif
