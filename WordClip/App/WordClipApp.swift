import SwiftUI
import SwiftData
import WordClipKit

@main
struct WordClipApp: App {

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
                .onOpenURL(perform: handleURL)
        }
        .modelContainer(modelContainer)
        .commands {
            WordClipCommands()
        }

        // ── 系统设置窗口（⌘, 触发）────────────────────────
        Settings {
            SettingsView()
                .environmentObject(entitlement)
                .environmentObject(appState)
        }

        // ── 状态栏图标 ────────────────────────────────────
        MenuBarExtra {
            MenuBarMenuView()
                .environmentObject(appState)
        } label: {
            // 取词启用时用实心剪刀，禁用时用半透明
            Label("WordClip", systemImage: "scissors")
                .symbolVariant(appState.captureEnabled ? .fill : .none)
                .opacity(appState.captureEnabled ? 1.0 : 0.4)
        }

        #else
        WindowGroup {
            ContentView()
                .environmentObject(entitlement)
                .environmentObject(appState)
                .onOpenURL(perform: handleURL)
        }
        .modelContainer(modelContainer)
        #endif
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
            let word = components.queryItems?.first(where: { $0.name == "word" })?.value
            _ = word  // TODO(M2): 触发收词流程
        case "review":
            break     // TODO(M3): 跳转复习页
        default:
            break
        }
    }
}
