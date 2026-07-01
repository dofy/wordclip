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
    private var dismissTask: Task<Void, Never>?

    /// 显示一条 HUD。
    /// - Parameters:
    ///   - symbol: SF Symbol 名
    ///   - tint: 图标色
    ///   - title: 主标题（通常是单词）
    ///   - subtitle: 副标题（释义首行 / 提示），可空
    ///   - duration: 停留秒数
    func show(symbol: String, tint: Color, title: String, subtitle: String?, duration: Double = 1.3) {
        dismissTask?.cancel()

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
            ctx.duration = 0.18
            panel.animator().alphaValue = 1
        }

        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    private func hide() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 0
        } completionHandler: {
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
