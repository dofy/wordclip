import SwiftUI
import SwiftData
import WordClipKit
#if os(macOS)
import UserNotifications
#endif

@main
struct WordClipApp: App {

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    // MARK: Dependencies
    // DEBUG 用 Mock(可切换模拟 Pro),Release 用真实 StoreKit。见 AppEntitlement.swift。
    #if DEBUG
    @StateObject private var entitlement = MockEntitlement(overridePro: false)
    #else
    @StateObject private var entitlement = StoreKitEntitlement()
    #endif
    @StateObject private var appState = AppState()

    // MARK: SwiftData 容器
    let modelContainer: ModelContainer = {
        let schema = Schema([
            WordEntry.self,
            CollectSource.self,
            ReviewLog.self,
            WordGroup.self,
        ])

        // 确保 Application Support 目录存在（iOS 沙盒里默认不存在，
        // SwiftData 不会自动创建，否则报 "file-write-create denied"）。
        let fm = FileManager.default
        if let appSupport = try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) {
            try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }

        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("SwiftData 容器初始化失败：\(error)")  // i18n-exempt: 崩溃日志，不面向用户
        }
    }()

    var body: some Scene {
        #if os(macOS)
        // ── 主窗口（单例 Window，非 WindowGroup）─────────────
        // 用 Window 而非 WindowGroup：后者会为每个进来的 wordclip:// URL 开新窗口。
        Window(String(localized: "app.name", defaultValue: "WordClip"), id: "main") {
            ContentView()
                .environmentObject(entitlement)
                .environmentObject(appState)
                .background(MainWindowConfigurator())
                // macOS 的 collect scheme 由 AppDelegate 统一处理（见下方 onReceive）
                .onReceive(NotificationCenter.default.publisher(for: .collectWordFromURL)) { note in
                    if let word = note.object as? String { collectFromURL(word) }
                }
                .task { await requestNotificationPermission() }
                .task { setupCollector() }
        }
        .modelContainer(modelContainer)
        .commands {
            WordClipCommands()
            // 禁掉系统默认的"新建窗口" (⌘N)
            CommandGroup(replacing: .newItem) { }
        }

        // ── 设置窗口（⌘,）────────────────────────────────
        Window(String(localized: "window.settings", defaultValue: "Settings"), id: "settings") {
            SettingsView()
                .environmentObject(entitlement)
                .environmentObject(appState)
                // 固定宽高:配合 .windowResizability(.contentSize) 锁住拖拽缩放。
                // 分区多时 Form 内部自动滚动。
                .frame(width: 520, height: 560)
                // 禁用绿灯(zoom/全屏):contentSize 关不掉全屏,需 NSWindow 层处理。
                .background(SettingsWindowConfigurator())
        }
        .windowResizability(.contentSize)
        // 永不响应外部 URL：否则 wordclip://collect 会被 SwiftUI 误路由到此窗口。
        .handlesExternalEvents(matching: [])
        // 启动时不自动弹出：设置窗口只应由 ⌘, / 菜单 / 状态栏显式打开。
        // 多 Window scene 默认都会在启动时呈现，导致设置窗口随主窗口一起冒出。
        .defaultLaunchBehavior(.suppressed)

        // ── 状态栏图标 ────────────────────────────────────
        MenuBarExtra {
            MenuBarMenuView()
                .environmentObject(appState)
                .modelContainer(modelContainer)
        } label: {
            // 自定义书签模板图，取词禁用时半透明提示
            Image("MenuBarIcon")
                .opacity(appState.captureEnabled ? 1.0 : 0.4)
        }

        #else
        WindowGroup {
            ContentView()
                .environmentObject(entitlement)
                .environmentObject(appState)
                .onOpenURL(perform: handleURL)   // iOS 无 handlesExternalEvents 冲突，直接处理
                .task { setupCollector() }
        }
        .modelContainer(modelContainer)
        #endif
    }

    /// 收录来自 URL scheme 的单词（collector 未就绪则排队）。
    @MainActor
    private func collectFromURL(_ word: String) {
        Task { @MainActor in
            if let collector = collectorBox.collector {
                await runCollect { await collector.collect(word: word) }
            } else {
                collectorBox.pendingWords.append(word)
            }
        }
    }

    // MARK: - URL Scheme Handler
    // wordclip://collect?word=serendipity
    // wordclip://review
    private func handleURL(_ url: URL) {
        guard url.scheme == "wordclip",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return }

        switch components.host {
        case "collect":
            if let word = components.queryItems?.first(where: { $0.name == "word" })?.value {
                Task { @MainActor in
                    if let collector = collectorBox.collector {
                        await runCollect { await collector.collect(word: word) }
                    } else {
                        // app 刚启动，collector 还没初始化完，先排队
                        collectorBox.pendingWords.append(word)
                    }
                }
            }
        case "review":
            break     // TODO: 跳转复习页
        default:
            break
        }
    }

    // collector 在主窗口出现时初始化一次，持有于引用盒中供回调/URL 复用。
    private let collectorBox = CollectorBox()

    @MainActor
    private func setupCollector() {
        guard collectorBox.collector == nil else { return }

        // 一次性迁移:存量 nil-group 老词归入手动组(见 Task 6b)。幂等,无 nil 词时空操作。
        WordPackStore(modelContext: modelContainer.mainContext).migrateOrphansToManualGroup()

        // 准备内置词典：从 Bundle 拷贝到 Application Support，只读打开。
        let builtin: DictionaryProvider
        do {
            let path = try DictionarySetup.prepareDatabasePath()
            builtin = try GRDBDictionaryProvider(dbPath: path)
        } catch {
            builtin = NullDictionaryProvider()
        }
        appState.builtinDictionary = builtin
        // 组合词库：内置 + 用户导入的词库
        let dictionary = DictionaryStore.shared.buildProvider(builtin: builtin)

        let collector = WordCollector(
            modelContext: modelContainer.mainContext,
            dictionary: dictionary
        )
        collectorBox.collector = collector
        appState.dictionary = dictionary
        appState.collector = collector   // 暴露给 UI（手输/粘贴）

        #if os(macOS)
        // 申请通知权限
        Task { await requestNotificationPermission() }

        // 注入全局热键回调
        appState.onCollect = { [weak appState] in
            guard let appState else { return }
            Task { @MainActor in
                let outcome = await collector.collectFromSelection()
                if case .notTrusted = outcome {
                    appState.needsAccessibilityPrompt = true
                }
                appState.flashCollectMessage(Self.feedback(for: outcome))
                Self.sendNotification(for: outcome)
            }
        }

        // OCR 取词回调：自带 Pro 闸门，免费用户弹付费墙。
        appState.onCollectOCR = { [weak appState] in
            guard let appState else { return }
            guard entitlement.isPro else { appState.presentPaywall(); return }
            Task { @MainActor in
                await Self.runOCRCapture(collector: collector, appState: appState)
            }
        }
        appState.refreshHotkeyRegistration()
        #endif

        // 消费 collector 就绪前积压的 URL 请求
        for word in collectorBox.pendingWords {
            Task { @MainActor in
                await runCollect { await collector.collect(word: word) }
            }
        }
        collectorBox.pendingWords.removeAll()
    }

    /// 统一执行收录并反馈：前台 toast + macOS 系统通知。
    @MainActor
    private func runCollect(_ action: () async -> WordCollector.CollectOutcome) async {
        let outcome = await action()
        appState.flashCollectMessage(Self.feedback(for: outcome))
        #if os(macOS)
        Self.sendNotification(for: outcome)
        #endif
    }

    /// 把收录结果转成给用户看的反馈文案。
    static func feedback(for outcome: WordCollector.CollectOutcome) -> String {
        switch outcome {
        case .collected(let word, let found, _):
            return found
                ? String(localized: "collect.success", defaultValue: "Collected: \(word)")
                : String(localized: "collect.success.nodef", defaultValue: "Collected: \(word) (no definition found)")
        case .noSelection:
            return String(localized: "collect.noselection", defaultValue: "No selected text detected")
        case .notTrusted:
            return String(localized: "collect.notrusted", defaultValue: "Grant Accessibility permission in System Settings")
        case .invalid:
            return String(localized: "collect.invalid", defaultValue: "Not a valid word")
        }
    }

    #if os(macOS)
    // MARK: - OCR 取词流程

    /// 框选屏幕 → 截图 → OCR → 弹选词面板。
    @MainActor
    private static func runOCRCapture(collector: WordCollector, appState: AppState) async {
        guard let selection = await RegionSelector().selectRegion() else {
            return   // 取消 / 选区过小：静默
        }

        let image: CGImage
        do {
            image = try await ScreenCapturer.capture(rect: selection.rect, on: selection.screen)
        } catch ScreenCapturer.CaptureError.permissionDenied {
            CollectHUD.shared.show(
                symbol: "exclamationmark.triangle.fill", tint: .orange,
                title: String(localized: "ocr.permission.denied",
                              defaultValue: "Grant Screen Recording permission in System Settings"),
                subtitle: nil, duration: 2.4
            )
            return
        } catch {
            CollectHUD.shared.show(
                symbol: "exclamationmark.triangle.fill", tint: .orange,
                title: String(localized: "ocr.capture.failed", defaultValue: "Screen capture failed, please try again"),
                subtitle: nil, duration: 2.0
            )
            return
        }

        // 截图已完成（未包含面板），此刻立即弹出「分析中」面板，覆盖 OCR 的等待感。
        // 面板显示在截图之后，确保它不会被拍进将要识别的图像里污染 OCR。
        OCRWordPicker.shared.presentAnalyzing { picked in
            Task { @MainActor in
                await Self.collectOCRWords(picked, collector: collector, appState: appState)
            }
        }

        let recognized = await ScreenOCR.recognizeWords(in: image)

        // 用户可能在分析期间已取消/关闭面板：放弃后续。
        guard OCRWordPicker.shared.isPresenting else { return }

        // 词典校验：只保留词典里真实存在的英文词，滤掉音标/噪声（如 maigreit、FREI）。
        // 额外滤掉「全大写且 ≤4 字母」的碎片（如 UPD/DEF/FAX/MP），这类多为词典 UI/缩写噪声。
        var words: [String] = []
        for word in recognized {
            let isShortAcronym = word.count <= 4 && word == word.uppercased()
            if isShortAcronym { continue }
            if await collector.dictionary.lookup(word.lowercased()) != nil {
                words.append(word)
            }
        }

        guard !words.isEmpty else {
            OCRWordPicker.shared.close()
            CollectHUD.shared.show(
                symbol: "text.viewfinder", tint: .orange,
                title: String(localized: "ocr.notext", defaultValue: "No English words recognized"),
                subtitle: nil, duration: 1.8
            )
            return
        }

        OCRWordPicker.shared.showWords(words)
    }

    /// 收录用户在选词面板里选中的词，HUD 汇总反馈。
    @MainActor
    private static func collectOCRWords(_ words: [String], collector: WordCollector, appState: AppState) async {
        var count = 0
        for word in words {
            let outcome = await collector.collect(word: word, sourceAppName: "OCR")
            if case .collected = outcome { count += 1 }
        }
        guard count > 0 else { return }
        CollectHUD.shared.show(
            symbol: "checkmark.circle.fill", tint: .green,
            title: String(localized: "ocr.captured", defaultValue: "Collected \(count) words"),
            subtitle: nil
        )
    }

    /// 仅设置通知 delegate（前台也能显示复习提醒）。
    /// 不在启动时申请权限——收词反馈已改用 HUD，只有「每日复习提醒」需要通知，
    /// 其权限在用户开启提醒时（NotificationService.scheduleReviewReminder）才按需申请。
    @MainActor
    private func requestNotificationPermission() async {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    /// 用悬浮 HUD 反馈收录结果（app 未激活时也能在任意 App 上方看到，
    /// 不进通知中心、无需权限、无声音）。
    @MainActor
    private static func sendNotification(for outcome: WordCollector.CollectOutcome) {
        switch outcome {
        case .collected(let word, let found, let definition):
            let sub = found
                ? definition?.components(separatedBy: "\n").first
                : String(localized: "notification.collect.nodef",
                         defaultValue: "Not in the dictionary, definition left empty")
            CollectHUD.shared.show(
                symbol: found ? "checkmark.circle.fill" : "checkmark.circle",
                tint: .green,
                title: word,
                subtitle: sub
            )
        case .notTrusted:
            CollectHUD.shared.show(
                symbol: "exclamationmark.triangle.fill",
                tint: .orange,
                title: String(localized: "collect.notrusted",
                              defaultValue: "Grant Accessibility permission in System Settings"),
                subtitle: nil,
                duration: 2.2
            )
        case .noSelection, .invalid:
            break
        }
    }
    #endif
}

/// 持有 WordCollector 的引用盒（App 是值类型，需引用类型跨回调保活）。
@MainActor
final class CollectorBox {
    var collector: WordCollector?
    /// collector 初始化前通过 URL scheme 进来的词，就绪后统一处理。
    var pendingWords: [String] = []
}

#if os(macOS)
/// 把设置窗口配置成固定尺寸的偏好式窗口：禁用绿灯(zoom/全屏)、移除全屏能力。
/// `.windowResizability(.contentSize)` 只锁拖拽缩放，关不掉全屏绿灯，需 NSWindow 层处理。
private struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }
    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        // 移除全屏能力，改为辅助行为(仍可覆盖在别的全屏窗上,但自身不进全屏)。
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        // 禁用/隐藏绿灯 zoom 按钮。
        if let zoom = window.standardWindowButton(.zoomButton) {
            zoom.isEnabled = false
        }
        window.styleMask.remove(.resizable)   // 双保险：去掉可缩放样式位
        // 不记住打开状态:退出时即使设置窗开着,下次启动也不恢复它。
        // .suppressed 只抑制「无待恢复场景」的情况,挡不住状态恢复,故在此关掉可恢复性。
        window.isRestorable = false
        // 交给 DockVisibility：accessory 状态下从状态栏打开设置窗口时，Dock 图标和菜单栏
        // 得跟着回来。
        DockVisibility.shared.adopt(window)
    }
}

/// 把主窗口交给 `DockVisibility`：接管 ⌘W / 红灯,并保证它可见时 Dock 图标是亮的。
///
/// identifier 显式设成 "main",状态栏的「打开 WordClip」和 `AppState.presentPaywall()`
/// 都按这个值找窗口。
private struct MainWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // 窗口被收起后再次出现时也要走一遍:SwiftUI 复用同一个内容视图,不会再调 makeNSView,
        // 而 Dock 图标此刻还是隐藏的。
        DispatchQueue.main.async { configure(nsView.window) }
    }

    private func configure(_ window: NSWindow?) {
        guard let window, window.isVisible else { return }
        window.identifier = NSUserInterfaceItemIdentifier(AppState.mainWindowIdentifier)
        window.isReleasedWhenClosed = false
        DockVisibility.shared.adopt(window)
    }
}
#endif
