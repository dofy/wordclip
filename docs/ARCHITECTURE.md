# 架构与关键技术决策

## 1. 整体结构

```
wordclip/                          # 仓库根（project.yml → xcodegen 生成 *.xcodeproj）
├── WordClip/                      # App target（macOS + iOS 共用，#if 分平台）
│   ├── App/                       # 入口、AppDelegate、AppState、命令、热键名
│   ├── Views/                     # SwiftUI 界面（列表/详情/复习/统计/设置…）
│   ├── Services/                  # 取词、HUD、朗读、复习会话、词典库、备份、通知
│   └── Resources/                 # 词库 SQLite、图标、Localizable.xcstrings
├── WordClipKit/Sources/WordClipKit/   # Swift Package —— 平台无关核心
│   ├── Models/                    # SwiftData 模型
│   ├── Dictionary/                # Provider 协议、GRDB 实现、复合库、导入器、释义解析
│   ├── Review/                    # 复习算法引擎（SM-2 / 可换 FSRS）
│   ├── Language/                  # LanguagePack 协议与英语实现
│   ├── Stats/                     # 统计计算
│   ├── Sync/                      # 备份数据结构（JSON 导入导出）
│   ├── Entitlement/               # EntitlementProvider 协议 + MockEntitlement
│   └── AI/                        # AIProvider 协议（预留）
├── data/                          # 词库构建脚本（不入库原始大文件）
└── docs/
```

> iOS Share Extension 尚未创建（见 PLAN「计划中方向」）。

**原则**：UI 层薄，业务逻辑全部在 `WordClipKit` 中并可被单元测试。这样未来要做 Web 端时，算法与数据 schema 可移植。

---

## 2. 数据模型（SwiftData）

```swift
@Model final class WordEntry {
    var id: UUID
    var headword: String          // 原始收集形态
    var lemma: String             // 归一化词元（用于去重/查词）
    var language: String          // "en" / "ja" ... 多语言关键字段
    var definition: String?       // 缓存的释义（来自词库或 AI）
    var phonetic: String?         // IPA
    var tags: [String]
    var createdAt: Date
    var sources: [CollectSource]  // 收集来源（可多次收集同一词）

    // 复习状态（SM-2）
    var familiarity: Int          // 0–4/5 熟悉度
    var easeFactor: Double        // SM-2 EF
    var interval: Int             // 天
    var repetitions: Int
    var dueAt: Date?
    var lastReviewedAt: Date?
}

@Model final class CollectSource {
    var collectedAt: Date
    var appName: String?          // 来源 App（macOS 可得）
    var contextSentence: String?  // 原句（若可捕获）
    var platform: String          // "macOS" / "iOS"
}

@Model final class ReviewLog {        // 每次测试记录，供统计与未来 FSRS 训练
    var date: Date
    var wordID: UUID
    var grade: Int
    var mode: String                  // 测试模式
}
```

CloudKit 要求：所有属性有默认值或可选、关系可选、不可用唯一约束。建模时遵守。

---

## 3. 关键技术方案

### 3.1 macOS 全局快捷键 + 捕获选中文本

**当前实现:方案 C —— 全局热键(`KeyboardShortcuts`)+ Accessibility API 直读选中文本(`AXUIElement`),不改动剪贴板。** 首次使用引导用户在「系统设置 → 隐私与安全性 → 辅助功能」授权。

早期评估过的三种方案:

| 方案 | 捕获方式 | 优点 | 缺点 |
|------|---------|------|------|
| A. Services 菜单 | 注册系统 Service,用户在选中文本上右键/快捷键触发 | 完全合规、无需特殊权限 | 非全局快捷键体验,需系统设置里启用 |
| B. 全局热键 + 模拟复制 | 热键 → 发送 ⌘C → 读剪贴板 | 真·全局体验 | 需 Accessibility 权限;会改动剪贴板 |
| **C. 全局热键 + Accessibility 直读**(已采用) | 热键 → `AXUIElement` 读聚焦元素选中文本 | 全局体验且不动剪贴板 | 需 Accessibility 权限,个别 App 不支持 |

> 上架时需在审核说明中解释辅助功能权限用途(读取选中文本以收词)。

### 3.2 读音

`AVSpeechSynthesizer`，离线，按 `WordEntry.language` 选 voice。词库中的 IPA 仅做展示。

### 3.3 离线词库

- 构建期：`data/` 脚本拉 ECDICT，裁剪字段（lemma/IPA/中英释义/词频），按词频可生成「常用 N 万词」精简版，导出 `dictionary-en.sqlite`。
- 运行期：`DictionaryProvider` 协议，SQLite 实现（GRDB 推荐）。词库随 App 分发，首启拷到 Application Support，只读查询。

```swift
protocol DictionaryProvider {
    func lookup(_ lemma: String) async -> DictionaryResult?
    func suggest(prefix: String, limit: Int) async -> [String]
}
```

- **词形还原**:`GRDBDictionaryProvider` 利用 ECDICT `exchange` 列,把变形词(`brought`)回退到原型(`bring`)查询。
- **复合词库**:`CompositeDictionaryProvider` 按优先级串联「内置 + 用户导入」的多个 Provider,lookup 取首个命中,suggest 合并去重。
- **自定义导入**:`DictionaryImporter` 把 CSV / ECDICT 结构 SQLite 转成词库文件,`DictionaryStore`(App 侧)管理已安装词典的启停/顺序,元数据存 UserDefaults、文件存 App Support。约束:只导入用户有权使用的词典,App 不分发第三方商业词典。

### 3.4 复习引擎

```swift
protocol ReviewEngine {
    func schedule(_ state: ReviewState, grade: Int, now: Date) -> ReviewState
}
struct SM2Engine: ReviewEngine { /* 标准 SM-2 */ }
// 未来：struct FSRSEngine: ReviewEngine
```

`ReviewLog` 持续记录，为日后切到 FSRS 留训练数据。

### 3.5 多语言扩展

```swift
protocol LanguagePack {
    var code: String { get }                  // "en" / "ja"
    var displayName: String { get }
    func tokenize(_ text: String) -> [String] // 英语简单切分；日语用 NaturalLanguage
    func makeDictionary() -> DictionaryProvider
    var ttsVoiceLanguage: String { get }
    var defaultReviewEngine: ReviewEngine { get }
}
```

- 当前内置 `EnglishPack`。
- 新增语言 = 新词库 SQLite + 一个 `LanguagePack` 实现 + 一个 build configuration / scheme。
- 「复制工程」仅作兜底，不作为主路径。

### 3.6 AI 接口（预留）

```swift
protocol AIProvider {
    func enrich(word: String, context: String?) async throws -> AIEnrichment
    // 释义增强、例句、词根/助记
}
```

先给 `NoopAIProvider` / `MockAIProvider` 占位，UI 留入口默认关闭。后续可接 Claude 等。

### 3.7 界面本地化（i18n）—— 与学习语言正交

**两个独立维度，不要混为一谈：**

| 维度 | 指 | 由谁决定 | 技术 |
|------|----|---------|------|
| 学习内容语言 | 用户在学的语言（en/ja…） | `LanguagePack`（App 内可切） | 词库 + 分词 + TTS |
| 界面语言 | 菜单/按钮显示语言 | 系统语言（用户在系统设置选） | String Catalog `.xcstrings` |

一个用中文系统的人，可以学英语、也可以学日语；界面始终中文。

**实施约定：**
- 所有用户可见文案一律 `String(localized: "...")` / SwiftUI `Text("...")` 自动本地化，**禁止硬编码**。
- 用 **String Catalog（`.xcstrings`）** 统一管理，首批配 `zh-Hans` + `en`。
- `WordClipKit` 中若有面向用户的字符串，也在 Package 内建自己的本地化资源（`defaultLocalization` + `.process` 资源），不把文案泄露到 UI 层。
- 词库释义本身的语言（如英译中 vs 英英）属于「学习内容」，由词库数据决定，与界面语言无关。

### 3.8 订阅与权益抽象（EntitlementProvider）

收费功能由一层抽象隔离，开发期可用 mock 跑通整套 paywall/Pro 边界，账号就绪后只换实现：

```swift
enum SubscriptionPlan { case monthly, yearly, lifetime }

protocol EntitlementProvider {
    var isPro: Bool { get }                       // 是否解锁 Pro
    var statePublisher: AnyPublisher<Bool, Never> { get }
    func purchase(_ plan: SubscriptionPlan) async throws
    func restore() async throws
    func products() async -> [PlanProduct]        // 价格/本地化标题
}

struct MockEntitlement: EntitlementProvider { ... }      // 开发期：开关即「已订阅」
// 账号就绪后：StoreKitEntitlement / RevenueCatEntitlement，UI 不变
```

- **功能闸门**统一走 `entitlement.isPro`，业务代码不直接碰 StoreKit。
- 免费/Pro 边界见 PLAN「收费计划」一节。

---

## 4. 同步策略：本地优先，云端后置

当前无付费开发者账号，**全程本地 SwiftData**，CloudKit 推迟（见 PLAN「计划中方向」）。设计上预留平滑切换：

```swift
// 本地阶段
let config = ModelConfiguration(isStoredInMemoryOnly: false)
// 账号就绪后，仅此处改为：
// let config = ModelConfiguration(cloudKitDatabase: .private("iCloud.com.example.WordClip"))
let container = try ModelContainer(for: WordEntry.self, /* ... */ configurations: config)
```

**为此从第一天起就遵守 CloudKit 建模约束**（即便当前不开云），避免日后迁移返工：
- 所有属性有默认值或可选；关系可选；不使用 `@Attribute(.unique)` 唯一约束（去重在应用层做）。

开云后：私有数据库自动增量同步；冲突以「最近修改」为主，复习状态取更靠前的进度。

---

## 4.5 收费与同步选型（决策：Apple 生态内起步）

**已确认路线：StoreKit 2（+ RevenueCat）做订阅 + CloudKit 做同步，零自建后端。** 权益判断在本地完成，跨设备权益与数据同步都交给 Apple 生态。未来若需网页端购买/跨平台账号，再引入自建后端——核心逻辑已沉淀在 `WordClipKit`，可平滑扩展。

| 关注点 | 选择 | 备注 |
|--------|------|------|
| 收费渠道 | **StoreKit 2 内购**（数字订阅强制走 IAP） | 起步可纯 StoreKit；引入 RevenueCat 省掉收据校验/跨设备权益同步 |
| 抽成 | 申请 **Small Business Program** → 15% | 年收入 < $100 万适用 |
| 同步 | **CloudKit 私有库** | 与 SwiftData 集成，见 §4 |
| 后端 | **暂不自建** | Apple 生态内一切由 StoreKit + CloudKit 托管 |

**红线提醒**：iOS 上数字商品/订阅不得用 Stripe/微信支付等外部渠道在 App 内完成交易，否则下架。这也是选 StoreKit 的根本原因。

> 前置条件：以上全部需要 Apple 付费开发者账号（$99/年）。当前用 `MockEntitlement`（见 §3.8）跑通 Pro 边界，账号就绪后换真实现。

---

## 5. 系统内置词典：为什么不作数据源

- **iOS**：`UIReferenceLibraryViewController` 只能弹出 Apple 查词界面，**无法读取文本**进自己的模型。
- **macOS**：`DCSCopyTextDefinition`（CoreServices）能取到纯文本，但①接口半公开，上架审核有风险；②返回格式不稳定、难结构化；③Apple 授权的牛津等词典内容仅用于「系统查词」，抽取入库属版权灰区。

**决策**：自带开源词库为唯一数据源；系统词典仅提供「跳转到系统查词」便捷入口（合规）。

---

## 6. 导入导出

- **当前实现**:`WordClipKit/Sync/WordBackup` 提供全量 JSON 备份(含单词、来源、复习进度),App 侧 `BackupService` + `WordBackupDocument` 负责导入/导出;导入按单词智能合并,不覆盖已有学习进度。
- 词典导入是另一条路径:`WordClipKit/Dictionary/DictionaryImporter` 把 CSV / ECDICT SQLite 转成可查词库(见 §3.3),与个人词库备份互不相关。
- 同步策略见上文 §4。

---

## 7. 测试策略

- `WordClipKit` 全量单元测试（算法、词库查询、导入导出、分词）—— 不依赖 UI，可在 CI（GitHub Actions macOS runner）跑 `swift test`。
- App 层只做必要的集成/快照测试。
