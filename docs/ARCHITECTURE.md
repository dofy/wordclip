# 架构与关键技术决策

## 1. 整体结构

```
WordClip/                      # Xcode 工程
├── WordClipKit/               # Swift Package —— 平台无关核心
│   ├── Models/                # SwiftData 模型
│   ├── Dictionary/            # 词库 Provider 协议与 SQLite 实现
│   ├── Review/                # 复习算法引擎（SM-2 / 可换 FSRS）
│   ├── Language/              # LanguagePack 协议与英语实现
│   ├── AI/                    # AIProvider 协议（预留）
│   └── ImportExport/          # CSV / JSON
├── Apps/
│   ├── macOS/                 # macOS App target（全局快捷键、状态栏）
│   ├── iOS/                   # iOS/iPad App target
│   └── ShareExtension/        # iOS 分享扩展
├── data/                      # 词库构建脚本（不入库原始大文件）
└── docs/
```

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

三选一，按「上架友好度」排序，M2 前定：

| 方案 | 捕获方式 | 优点 | 缺点 |
|------|---------|------|------|
| **A. Services 菜单**（推荐起步） | 注册系统 Service，用户在选中文本上右键/快捷键触发 | 完全合规、可上架、无需特殊权限 | 需用户在系统设置里启用一次 |
| **B. 全局热键 + 模拟复制** | `Carbon RegisterEventHotKey` 或 `CGEvent` 热键 → 发送 ⌘C → 读剪贴板 | 真·全局快捷键体验 | 需 Accessibility 权限；会改动剪贴板（可保存后还原） |
| **C. Accessibility API 直读** | `AXUIElement` 读取聚焦元素选中文本 | 不动剪贴板 | 权限要求高，部分 App 不支持 |

建议：**A 作为合规基线，B 作为「随处可用」增强**，给用户开关选择。

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

---

## 4. 系统内置词典：为什么不作数据源

- **iOS**：`UIReferenceLibraryViewController` 只能弹出 Apple 查词界面，**无法读取文本**进自己的模型。
- **macOS**：`DCSCopyTextDefinition`（CoreServices）能取到纯文本，但①接口半公开，上架审核有风险；②返回格式不稳定、难结构化；③Apple 授权的牛津等词典内容仅用于「系统查词」，抽取入库属版权灰区。

**决策**：自带开源词库为唯一数据源；系统词典仅提供「跳转到系统查词」便捷入口（合规）。

---

## 5. 同步与导入导出

- **同步**：SwiftData 的 CloudKit 集成（`ModelConfiguration(cloudKitDatabase:)`），私有数据库，自动增量同步。冲突以「最近修改」为主，复习状态取更靠前的进度。
- **导入导出**：`ImportExport` 模块，CSV（headword, lemma, definition, phonetic, tags, familiarity, dueAt…）与 JSON（全量含来源/日志）。导入做字段映射与去重。

---

## 6. 测试策略

- `WordClipKit` 全量单元测试（算法、词库查询、导入导出、分词）—— 不依赖 UI，可在 CI（GitHub Actions macOS runner）跑 `swift test`。
- App 层只做必要的集成/快照测试。
