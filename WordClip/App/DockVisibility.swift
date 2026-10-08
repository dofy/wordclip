#if os(macOS)
import AppKit

/// Dock 图标的显隐：窗口全收起时把 app 切成 accessory,只留状态栏图标。
///
/// 机制是 `NSApplication.setActivationPolicy`,不是另起后台进程。切到 `.accessory` 后
/// 进程照常活着、`MenuBarExtra` 照常显示、全局热键(走 Carbon)照常触发,消失的只有 Dock
/// 图标和应用菜单栏。`LSUIElement` 是这件事的静态版本(永久 accessory),这里要的是随窗口
/// 动态切换,所以 Info-macOS.plist 不碰,app 仍以 `.regular` 启动。
///
/// ⌘W 和红灯都被接管成「收起窗口」而不是真关:主窗口是单例 `Window` 场景,真关会让 SwiftUI
/// 把场景连窗口对象一起拆掉,重开要走 `openWindow(id:)` 重建视图树,侧边栏选中的分组和滚动
/// 位置都得重来。`orderOut` 全保得住。不换 `NSWindowDelegate` 来拦 `windowShouldClose:`:
/// 那个 delegate 是 SwiftUI 自己的,顶掉它就得手工转发整个 NSWindowDelegate,漏一个方法就
/// 破坏场景记账。
///
/// 「还有没有窗口在屏幕上」只认显式登记过的窗口,不去过滤 `NSApp.windows`。app 里有一堆
/// 辅助窗口——`CollectHUD` 的悬浮面板、OCR 选词面板、截屏遮罩、`MenuBarExtra` 的宿主窗口
/// ——按类型和 window level 猜哪些"不算",猜漏一个就表现为 Dock 图标该消失时不消失。
@MainActor
final class DockVisibility: NSObject {
    static let shared = DockVisibility()

    /// 设置项：窗口全收起后是否隐藏 Dock 图标。持久化在这里,`AppState` 只做 SwiftUI 绑定的
    /// 镜像,避免同一个键两个所有者。
    var hidesDockWhenClosed: Bool {
        didSet {
            guard hidesDockWhenClosed != oldValue else { return }
            UserDefaults.standard.set(hidesDockWhenClosed, forKey: Self.defaultsKey)
            reevaluate()
        }
    }

    static let defaultsKey = "hidesDockWhenClosed"

    /// 登记过的窗口,弱引用。只有主窗口和设置窗口会进来。
    private let adopted = NSHashTable<NSWindow>.weakObjects()
    private var closeMonitor: Any?
    private var closeObserver: NSObjectProtocol?

    private override init() {
        // 键不存在时 `bool(forKey:)` 返回 false,而这个开关默认是开的,所以先探键是否存在。
        let defaults = UserDefaults.standard
        hidesDockWhenClosed = defaults.object(forKey: Self.defaultsKey) == nil
            ? true
            : defaults.bool(forKey: Self.defaultsKey)
        super.init()
    }

    /// 装上 ⌘W 拦截和窗口关闭观察。在 `applicationDidFinishLaunching` 里调一次。
    func install() {
        guard closeMonitor == nil else { return }

        // 局部事件监听比菜单的 key equivalent 先拿到事件,所以这里能把 ⌘W 整个吃掉。
        closeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
                  event.charactersIgnoringModifiers?.lowercased() == "w",
                  let window = NSApp.keyWindow,
                  adopted.contains(window)
            else { return event }

            hide(window)
            return nil
        }

        // 「文件 → 关闭」没被接管,走的是真关。窗口内容会丢,但 Dock 图标同样要跟着收起,
        // 所以这条路也得能触发重算。
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: nil
        ) { _ in
            Task { @MainActor in DockVisibility.shared.reevaluate() }
        }
    }

    /// 登记一个真窗口：接管它的红灯,并确保 Dock 图标这会儿是亮的。
    ///
    /// 由窗口内容视图在出现时调用,所以不管窗口是被热键、URL scheme、状态栏菜单还是 ⌘,
    /// 打开的,都会经过这里——不需要在每个入口各插一次桩。
    func adopt(_ window: NSWindow) {
        if !adopted.contains(window) {
            adopted.add(window)
            if let closeButton = window.standardWindowButton(.closeButton) {
                closeButton.target = self
                closeButton.action = #selector(closeButtonPressed(_:))
            }
        }
        showDockIcon()
    }

    /// 切回 `.regular` 并激活。
    func showDockIcon() {
        guard NSApp.activationPolicy() != .regular else { return }
        NSApp.setActivationPolicy(.regular)
        // 切完 policy 的同一轮 runloop 里 activate 常常不生效：菜单栏不换、窗口抢不到前台。
        // 下一拍再激活。
        Task { @MainActor in NSApp.activate(ignoringOtherApps: true) }
    }

    /// 按当前窗口可见性和设置项重算 activation policy。
    func reevaluate() {
        // `willCloseNotification` 触发时窗口还算 `isVisible`,当场数会把它数进去。延一拍。
        Task { @MainActor in
            let target = Self.policy(
                hidesDockWhenClosed: hidesDockWhenClosed,
                hasVisibleWindow: adopted.allObjects.contains(where: \.isVisible)
            )
            guard NSApp.activationPolicy() != target else { return }
            NSApp.setActivationPolicy(target)
            if target == .accessory {
                // 不 deactivate 的话菜单栏会留着 WordClip 的菜单直到焦点自己移走。
                // 顺带把焦点还给用户按 ⌘W 之前那个 app。
                NSApp.deactivate()
            }
        }
    }

    /// policy 的决策规则,单独拎出来是为了讲清真值表。
    // nonisolated：纯函数,不碰实例状态。类带 @MainActor,静态方法会跟着继承隔离,
    // 测试就调不动了。
    nonisolated static func policy(
        hidesDockWhenClosed: Bool,
        hasVisibleWindow: Bool
    ) -> NSApplication.ActivationPolicy {
        if hasVisibleWindow { return .regular }
        return hidesDockWhenClosed ? .accessory : .regular
    }

    /// 把已登记的窗口重新拉到前台。窗口被 `orderOut` 而不是销毁,所以对象还在。
    /// 找不到就返回 false,由调用方走 `openWindow(id:)` 重建。
    func reopenWindow(identifier: String) -> Bool {
        guard let window = adopted.allObjects.first(where: {
            $0.identifier?.rawValue == identifier
        }) else { return false }
        showDockIcon()
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    private func hide(_ window: NSWindow) {
        window.orderOut(nil)
        reevaluate()
    }

    @objc private func closeButtonPressed(_ sender: Any?) {
        guard let window = (sender as? NSView)?.window else { return }
        hide(window)
    }
}
#endif
