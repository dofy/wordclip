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
    @StateObject private var entitlement = MockEntitlement(overridePro: false)
    @StateObject private var appState = AppState()

    // MARK: SwiftData 容器
    let modelContainer: ModelContainer = {
        let schema = Schema([
            WordEntry.self,
            CollectSource.self,
            ReviewLog.self,
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
            fatalError("SwiftData 容器初始化失败：\(error)")
        }
    }()

    var body: some Scene {
        #if os(macOS)
        // ── 主窗口 ───────────────────────────────────────
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(entitlement)
                .environmentObject(appState)
                // macOS 的 collect scheme 由 AppDelegate 统一处理（见下方 onReceive）
                .onReceive(NotificationCenter.default.publisher(for: .collectWordFromURL)) { note in
                    if let word = note.object as? String { collectFromURL(word) }
                }
                .task { await requestNotificationPermission() }
                .task { setupCollector() }
        }
        .handlesExternalEvents(matching: ["main"])  // URL 唤起时复用已有窗口
        .modelContainer(modelContainer)
        .commands {
            WordClipCommands()
            // 禁掉系统默认的"新建窗口" (⌘N)
            CommandGroup(replacing: .newItem) { }
        }

        // ── 设置窗口（⌘,）────────────────────────────────
        Window(String(localized: "window.settings", defaultValue: "设置"), id: "settings") {
            SettingsView()
                .environmentObject(entitlement)
                .environmentObject(appState)
                .frame(minWidth: 420, minHeight: 320)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 520, height: 400)
        // 永不响应外部 URL：否则 wordclip://collect 会被 SwiftUI 误路由到此窗口。
        .handlesExternalEvents(matching: [])

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
                ? String(localized: "collect.success", defaultValue: "已收录：\(word)")
                : String(localized: "collect.success.nodef", defaultValue: "已收录：\(word)（未找到释义）")
        case .noSelection:
            return String(localized: "collect.noselection", defaultValue: "未检测到选中的文本")
        case .notTrusted:
            return String(localized: "collect.notrusted", defaultValue: "需要在系统设置中授予辅助功能权限")
        case .invalid:
            return String(localized: "collect.invalid", defaultValue: "不是有效的单词")
        }
    }

    #if os(macOS)
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
                         defaultValue: "词典未收录该词，释义留空")
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
                              defaultValue: "需要在系统设置中授予辅助功能权限"),
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
