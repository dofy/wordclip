#if os(macOS)
import SwiftUI
import AppKit

/// 把授权横幅装进窗口 titlebar 的 accessory,而不是和 NavigationSplitView 平级堆叠。
///
/// 堆叠(VStack { Banner; NavigationSplitView })会把 split view 整体下推,但 AppKit
/// 仍按「内容紧贴工具栏」给详情栏的列表留顶部 content inset,并在那里画那条玻璃带。
/// 带子于是浮在横幅下面,把列表首行糊掉。macOS 27 上逐个验证过:
/// `scrollEdgeEffectHidden(_:for: .top)`、`scrollEdgeEffectStyle(.hard, for: .top)`、
/// `toolbarBackgroundVisibility(.hidden, for: .windowToolbar)`、把横幅换成
/// `safeAreaInset(edge: .top)` 都消不掉它。
///
/// 装成 titlebar accessory 后,AppKit 把横幅算进 titlebar 高度,content inset 和玻璃带
/// 重新落回横幅上方,首行不再被盖。
struct TitlebarBannerInstaller: NSViewRepresentable {
    /// 横幅是否显示。变 false 时移除 accessory。
    let visible: Bool
    /// 横幅自己是独立的 hosting view,拿不到外层的 environmentObject,得显式传。
    let appState: AppState

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = WindowWatcherView()
        view.frame = .zero
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? WindowWatcherView else { return }
        let coordinator = context.coordinator
        let visible = self.visible
        let appState = self.appState
        // 窗口要等视图挂上去才有,makeNSView 时还是 nil;所以同步逻辑挂在
        // viewDidMoveToWindow 上,并在每次 update 时用最新的 visible 重装一遍。
        view.onSync = { [weak view] in
            coordinator.sync(window: view?.window, visible: visible, appState: appState)
        }
        view.onSync?()
    }

    final class Coordinator {
        private var accessory: NSTitlebarAccessoryViewController?

        func sync(window: NSWindow?, visible: Bool, appState: AppState) {
            guard let window else { return }

            if visible {
                guard accessory == nil else { return }
                let hosting = NSHostingView(
                    rootView: AccessibilityBanner().environmentObject(appState)
                )
                hosting.frame = NSRect(
                    x: 0, y: 0,
                    width: window.frame.width,
                    height: hosting.fittingSize.height
                )
                hosting.autoresizingMask = [.width]

                let controller = NSTitlebarAccessoryViewController()
                controller.layoutAttribute = .bottom
                controller.view = hosting
                window.addTitlebarAccessoryViewController(controller)
                accessory = controller
            } else if let controller = accessory {
                if let index = window.titlebarAccessoryViewControllers.firstIndex(of: controller) {
                    window.removeTitlebarAccessoryViewController(at: index)
                }
                accessory = nil
            }
        }
    }
}

/// 只为拿到 window:SwiftUI 里没有窗口句柄,靠 viewDidMoveToWindow 回调。
private final class WindowWatcherView: NSView {
    var onSync: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onSync?()
    }
}
#endif
