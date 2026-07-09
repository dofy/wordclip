# 全面上 App Store:macOS 取词机制沙盒化改造 — 设计文档

> **⛔ 已否决(2026-07-09)** —— 本文档记录的「沙盒化上 MAS」方向已放弃。
> 决策:macOS 保留原生全局取词(Accessibility 直读),走 **Developer ID + 公证 + 网站分发**,不上 Mac App Store。
> 根因:沙盒禁止跨 App 读取选中文本,与全局取词不可兼得;沙盒替代方案(合成⌘C / 快捷指令 / App Intents)均需牺牲开箱即用的取词体验。
> 现行决策见 `docs/ARCHITECTURE.md` §3.1 与 `docs/PLAN.md`「分发路线」。本文档仅作历史留档,勿据此实现。
>
> 日期:2026-07-08 · 状态:~~已定稿待实现~~ → **已否决**
> 依据调研:`.superpowers/research/sandbox-global-capture.md`(sandbox 兼容性)

## 背景与决策

WordClip 决定**全面上 App Store**(iOS + macOS 均走官方商店)。当前 macOS 版为实现"选中收词"用 `AXUIElementCreateSystemWide` **跨 App 读取其他进程的 Accessibility 数据**,这与 App Sandbox 根本冲突(Apple 硬性设计限制,无 entitlement 例外),导致无法上 Mac App Store。

**决策(已与产品方确认)**:
- **单版本全切 MAS**——放弃 AX 直读,macOS 只保留沙盒版。不做双版本(维护成本对独立开发者过重)。
- 选中收词改为 **CGEventTap 全局热键 + 合成 ⌘C + 读剪贴板 + 自动恢复原剪贴板** 方案(Bob 同类做法)。
- 剪贴板污染处理:**取词后自动恢复原内容**。

## 改造范围(仅一处机制,其余不动)

| 功能 | 现状 | 改造后 |
|------|------|--------|
| 选中收词(⌥⌘C) | AX 直读其他 App | **改**:热键 → 模拟 ⌘C → 读剪贴板 → 恢复剪贴板 |
| OCR 收词(⌥⌘O) | ScreenCaptureKit + Vision | ✅ **不变**(ScreenCaptureKit 沙盒兼容,是 Apple 推荐 API;屏幕录制 TCC 权限与沙盒不冲突) |
| URL scheme 收词 | AppDelegate | ✅ 不变 |
| 全局热键注册 | `KeyboardShortcuts`(Carbon RegisterEventHotKey) | ✅ 不变(Carbon 热键沙盒兼容) |
| iOS 全部 | — | ✅ 完全不受影响 |

## 核心设计:重写 SelectionReader 内部实现

**关键策略:保持 `SelectionReader` 的公开接口不变,只换内部实现,调用方零改动。**

现有调用方(不改):
- `AppState.needsAccessibilityPrompt` ← `SelectionReader.isTrusted`
- `WordCollector` ← `SelectionReader.isTrusted` / `.selectedText()`
- `AccessibilityBanner` ← `SelectionReader.openAccessibilitySettings()`
- `WordClipApp` / `ContentView` ← `needsAccessibilityPrompt`

保留同名成员(语义改为"输入监听"权限):
- `static var isTrusted: Bool` → 内部改判 `CGPreflightListenEventAccess()`
- `static func selectedText() -> String?` → 内部改为剪贴板方案(见下)
- `static func promptForAccessibility()` → 改为 `CGRequestListenEventAccess()`(请求输入监听)
- `static func openAccessibilitySettings()` → 改为打开"输入监听"设置面板(`x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`)

> 命名可保留旧名以最小化调用方改动,但建议把面向"辅助功能"语义的名字/文案更新为"输入监听"(见下"命名"小节)。

### 新 selectedText() 流程

```
1. 快照剪贴板:保存 NSPasteboard.general 所有 pasteboardItems(多 type)+ 记录 changeCount
2. 合成 ⌘C:CGEvent keyDown(c, .maskCommand) + keyUp,post 到 .cghidEventTap
3. 轮询等待:在超时(建议 ≤300ms,分多次 ~10–20ms 轮询)内等 changeCount 变化
4. 读取:changeCount 变化后读 NSPasteboard.general.string(forType: .string)
5. 恢复:清空并写回步骤 1 快照的 items(务必在读取之后)
6. 返回:trim 后非空则返回;超时未变化 → 返回 nil(视为"未选中文本")
```

### 6 个风险点与对策

1. **权限:输入监听(Input Monitoring)** — CGEventTap 合成/监听需 `CGRequestListenEventAccess`,独立于辅助功能的 TCC 权限。首启引导授权 + 提示需重启 App 生效。
2. **时序竞态(最大风险)** — 模拟 ⌘C 异步,系统写剪贴板有延迟。**必须轮询 changeCount**(非固定 sleep),检测到变化再读;恢复必须在读取之后,否则读到旧值。
3. **未选中文本** — ⌘C 复制不到 → changeCount 不变 → 超时 → 返回 nil,`WordCollector` 提示"未检测到选中文本",不误收。
4. **剪贴板恢复的无损性** — 快照保留 `NSPasteboardItem` 的所有 type(不只纯文本),尽力无损恢复;图片/文件等复杂类型尽力而为(文档说明边界)。
5. **热键注册** — 复用现有 `KeyboardShortcuts`(Carbon,沙盒兼容),不改。只换"读取选中文本"实现。
6. **部分 App 失败** — 自绘 UI(终端、部分 Electron)⌘C 行为不一致,取词可能失败。剪贴板方案固有局限,文档如实说明,不硬保证 100%。

## 配套改动

### entitlements(`WordClip-macOS.entitlements`)
当前为空(注释说明关沙盒)。改为:
- `com.apple.security.app-sandbox` = `true`
- `com.apple.security.files.user-selected.read-only`(词典/备份导入)
- `com.apple.security.files.user-selected.read-write`(备份导出 fileExporter)
- (iCloud 同步落地时再加 `com.apple.security.network.client` + CloudKit 容器;本次不做)
- 注:输入监听、屏幕录制是 TCC 运行时权限,**不通过 entitlement 声明**,无需在此加。

### 签名 / project.yml(macOS target)
- `CODE_SIGN_STYLE: Manual` + Developer ID 指纹 → 改为 MAS 分发签名(与 iOS 一致的自动签名或 Apple Distribution),`DEVELOPMENT_TEAM` 复用。
- 保留 `CODE_SIGN_ENTITLEMENTS` 指向更新后的 entitlements。
- 具体证书/描述文件配置以本机 Xcode 账号实际可用者为准(实现时确认)。

### 收费
- MAS 版直接用**现有 StoreKit 2 骨架**(`.storekit` 已就位)——比网站版简单,**不需要** Lemon Squeezy 等第三方付费。`.superpowers/research/macos-payment-licensing.md` 的第三方方案本次用不上(留档备未来网站版可能)。

### 权限引导 UI(`AccessibilityBanner`)
- 文案从"辅助功能"改为"输入监听";跳转目标改为输入监听设置面板。
- 相关 String Catalog key 的值同步(zh + en);`needsAccessibilityPrompt` 逻辑不变(只是判据从 AXIsProcessTrusted 变 CGPreflightListenEventAccess)。

### 命名(可选但建议)
- `SelectionReader` 内部注释、`AccessibilityBanner` 文案里"辅助功能"→"输入监听";变量名 `needsAccessibilityPrompt` 可保留(改动面小)或改 `needsInputMonitoringPrompt`(更准确但要动多处)。**实现时倾向保留变量名、只改用户可见文案**,降低风险。

### 文档
- `ARCHITECTURE.md §3.1`:重写取词方案——从"方案 C(AX 直读)"改为"沙盒 + CGEventTap 剪贴板方案",更新方案对比表与"上架"注记。
- `PLAN.md` / `PROGRESS.md`:macOS 分发从"开发者 ID 网站分发"→"Mac App Store";收词描述更新。
- `HELP.md`:macOS 收词权限说明从"辅助功能"→"输入监听";剪贴板行为说明(取词瞬间占用剪贴板并自动恢复)。
- `DICTIONARY-LICENSING.md`:删除/修正"macOS 只能网站分发"的表述。
- `TERMS.md §7`:macOS 从"开发者 ID 网站分发"改为"App Store 分发"。

## 测试

- **`SelectionReader` 剪贴板逻辑难以纯单测**(依赖真实 NSPasteboard + 系统事件)。核心验证靠:
  - Kit 层:若能抽出"剪贴板快照/恢复"纯逻辑(不依赖系统事件的部分),补单测;否则不强求。
  - **运行时手动验证**(关键):沙盒构建下,在 Safari/备忘录/Word 等选中单词按 ⌥⌘C,确认①能取到词 ②剪贴板原内容被恢复 ③未选中时不误收。
  - OCR 收词回归:确认沙盒下 ScreenCaptureKit 仍工作。
  - 词典导入/备份导出:确认沙盒 + user-selected entitlement 下文件读写正常。
- 两端 `xcodebuild` 通过;Kit 现有 70 测试不受影响。

## 文件清单

- `WordClip/Services/SelectionReader.swift`:重写内部实现(CGEventTap + 剪贴板),保留公开接口名。
- `WordClip/Resources/WordClip-macOS.entitlements`:开沙盒 + user-selected 文件 entitlement。
- `project.yml`:macOS target 签名配置改 MAS。
- `WordClip/Views/AccessibilityBanner.swift`:权限文案/跳转改"输入监听"。
- `WordClip/Resources/Localizable.xcstrings`:相关权限文案 key 的值(zh+en)。
- `WordClip/App/AppState.swift` / `WordClipApp.swift`:仅在 `SelectionReader` 判据变化处微调(尽量不动)。
- 文档:ARCHITECTURE / PLAN / PROGRESS / HELP / DICTIONARY-LICENSING / TERMS。

## 非目标(YAGNI)

- 不做双版本(网站版 AX 直读不保留)。
- 不改 OCR / URL scheme / iOS 任何逻辑。
- 不引入第三方付费(MAS 用 StoreKit)。
- 本次不落地 iCloud 同步(仅在 entitlements 预留说明,不实装)。
- 不追求 100% App 兼容(自绘 UI 的 App 取词失败是剪贴板方案固有局限,文档说明)。

## 风险与回退

- **最大风险**:剪贴板方案时序竞态导致取词不稳定,或部分 App 失败率偏高,体验明显劣于 AX 直读。
- **回退**:改造在独立分支/提交进行;若沙盒版体验不达标,可回退到 AX 直读 + 网站分发(git 历史保留),或重启双版本方案。
- 建议实现后**真机多 App 实测取词成功率**再决定是否提审。
