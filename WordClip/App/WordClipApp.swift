import SwiftUI
import SwiftData
import WordClipKit

@main
struct WordClipApp: App {

    // MARK: Dependencies
    // 开发期用 Mock；账号就绪后换 StoreKitEntitlement
    @StateObject private var entitlement = MockEntitlement(overridePro: false)

    // MARK: SwiftData 容器
    // 纯本地配置。账号就绪后只需将 configuration 改为 CloudKit 版本。
    let modelContainer: ModelContainer = {
        let schema = Schema([
            WordEntry.self,
            CollectSource.self,
            ReviewLog.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
            // CloudKit 就绪后替换为：
            // cloudKitDatabase: .private("iCloud.com.yourname.WordClip")
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("SwiftData 容器初始化失败：\(error)")
        }
    }()

    var body: some Scene {
        #if os(macOS)
        WindowGroup {
            ContentView()
                .environmentObject(entitlement)
        }
        .modelContainer(modelContainer)
        .commands {
            WordClipCommands()
        }
        #else
        WindowGroup {
            ContentView()
                .environmentObject(entitlement)
        }
        .modelContainer(modelContainer)
        #endif
    }
}
