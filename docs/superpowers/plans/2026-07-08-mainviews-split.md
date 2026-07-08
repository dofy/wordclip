# MainViews.swift 按职责拆分 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 1410 行的 MainViews.swift 按职责拆成 3 个新文件(SidebarView/SettingsView/WordListView),删除 MainViews.swift。纯结构重构,不改功能。

**Architecture:** 逐类型「剪切-移动」:每个任务把一组类型从 MainViews.swift 剪出、粘到新文件(带按需 import)。每步类型只存在于一处,故每步都能独立编译。全部同一 App module,跨文件引用零成本。

**Tech Stack:** SwiftUI(多平台)· XcodeGen(folder 引用,新文件自动纳入,需 `xcodegen generate`)。

## Global Constraints

- Swift 6,macOS 15+ / iOS 18+。
- **纯移动**:逐类型整段剪切,不改类型内部一个字符、不改签名/文案/key。
- 每个新文件带按需 import(见各任务);`SwiftUI` 必备。
- 新文件落 `WordClip/Views/`(已纳入 XcodeGen folder 引用),**不改 project.yml**;每次改动后 `xcodegen generate` 让新文件进编译目标。
- 无 Kit 改动、无文案/文档改动。
- 每步:剪切→粘贴→xcodegen→两端构建→提交。每任务结束时 MainViews.swift 对应类型已不在原处(避免重定义)。

---

## File Structure

- `WordClip/Views/SidebarView.swift`(新)— SidebarView
- `WordClip/Views/SettingsView.swift`(新)— SettingsView
- `WordClip/Views/WordListView.swift`(新)— WordSort + WordSelection + WordListView + WordDetailPane + DictionaryPreviewPane
- `WordClip/Views/MainViews.swift`(Task 3 末删除)

各类型当前行范围(MainViews.swift):SidebarView 10–27;WordSort 28–72;WordSelection 73–80;WordListView 81–820;WordDetailPane 821–1011;DictionaryPreviewPane 1012–1079;SettingsView 1080–1410。

---

### Task 1: 抽出 SidebarView

**Files:**
- Create: `WordClip/Views/SidebarView.swift`
- Modify: `WordClip/Views/MainViews.swift`(删除 SidebarView 段)

**Interfaces:**
- Consumes: `SidebarItem`(定义在 ContentView.swift,同 module 可见)。
- Produces: `SidebarView` 在新文件(ContentView 仍引用,不变)。

- [ ] **Step 1: 读取 SidebarView 完整代码**

Read `WordClip/Views/MainViews.swift` 的 SidebarView 段(约 9–27 行,含其上方 `/// macOS 侧边栏` 文档注释)。这是要移动的完整内容。

- [ ] **Step 2: 创建 SidebarView.swift**

创建 `WordClip/Views/SidebarView.swift`,内容 = `import SwiftUI` + 空行 + 从 MainViews 复制的 SidebarView 完整段(含文档注释)。只需 `import SwiftUI`(该类型不用 SwiftData/WordClipKit)。

- [ ] **Step 3: 从 MainViews.swift 删除 SidebarView 段**

用 Edit 删除 MainViews.swift 里的 SidebarView 段(含其文档注释),使该类型只存在于新文件。MainViews 顶部 import 保持不动(其余类型还需要)。

- [ ] **Step 4: xcodegen + 构建 macOS**

Run: `cd /Users/seven/Works/github/wordclip && xcodegen generate >/dev/null 2>&1 && xcodebuild -project WordClip.xcodeproj -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -3`
Expected: `** BUILD SUCCEEDED **`(若报 SidebarView 重定义 → 说明 MainViews 没删干净;若报 undefined → 说明新文件没进编译,检查 xcodegen)。

- [ ] **Step 5: 提交**

```bash
git add WordClip/Views/SidebarView.swift WordClip/Views/MainViews.swift WordClip.xcodeproj 2>/dev/null; git add -A
git commit -m "refactor: 抽出 SidebarView 到独立文件"
```
> 注:`.xcodeproj` 已 gitignore,`git add WordClip.xcodeproj` 会被忽略(无害);`git add -A` 只会纳入两个 .swift 文件。

---

### Task 2: 抽出 SettingsView

**Files:**
- Create: `WordClip/Views/SettingsView.swift`
- Modify: `WordClip/Views/MainViews.swift`(删除 SettingsView 段)

**Interfaces:**
- Consumes: `DictionarySettingsSection`(独立文件,已存在)、`WordBackupDocument`、`BackupService`、`MockEntitlement`、`AppState`(均同 module 或 Kit)。
- Produces: `SettingsView` 在新文件(ContentView + WordClipApp 仍引用,不变)。

- [ ] **Step 1: 读取 SettingsView 完整代码**

Read MainViews.swift 的 SettingsView 段(约 1079–1410 行,含其上方文档注释到文件末)。注意该段内含 `#if os(macOS)` 的快捷键录制字段与 `.formStyle(.grouped)` 等,以及 fileExporter/fileImporter。

- [ ] **Step 2: 创建 SettingsView.swift**

创建 `WordClip/Views/SettingsView.swift`,import 块:

```swift
import SwiftUI
import SwiftData
import WordClipKit
import UniformTypeIdentifiers
#if os(macOS)
import KeyboardShortcuts
#endif
```

其后粘贴从 MainViews 复制的 SettingsView 完整段(含文档注释)。逐字保留,不改内部。

- [ ] **Step 3: 从 MainViews.swift 删除 SettingsView 段**

用 Edit 删除 MainViews.swift 里的 SettingsView 段(含文档注释),该类型只存在于新文件。

- [ ] **Step 4: xcodegen + 构建 macOS + iOS**

Run: `cd /Users/seven/Works/github/wordclip && xcodegen generate >/dev/null 2>&1 && xcodebuild -project WordClip.xcodeproj -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -3`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild -project WordClip.xcodeproj -scheme WordClip-iOS -configuration Debug -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -2`
Expected: `** BUILD SUCCEEDED **`(iOS 验证 `#if os(macOS)` 的 KeyboardShortcuts import 被正确条件编译排除)。

- [ ] **Step 5: 提交**

```bash
git add -A
git commit -m "refactor: 抽出 SettingsView 到独立文件"
```

---

### Task 3: 抽出生词本三栏 + 删除 MainViews.swift

**Files:**
- Create: `WordClip/Views/WordListView.swift`
- Delete: `WordClip/Views/MainViews.swift`(迁出后应只剩顶部 import + 文件注释)

**Interfaces:**
- Consumes: `WordEntry`/`WordGroup`(Kit)、`DictionaryProvider`、`WordListActions`、`Speaker`、`WordSelection`(本文件内)、`SidebarItem`(ContentView)、`AppState`。
- Produces: `WordSort` / `WordSelection` / `WordListView` / `WordDetailPane` / `DictionaryPreviewPane` 在新文件(ContentView 引用 WordListView 不变)。

- [ ] **Step 1: 读取剩余全部类型**

此时 MainViews.swift 应只剩:顶部 import(9 行)+ WordSort + WordSelection + WordListView + WordDetailPane + DictionaryPreviewPane(SidebarView/SettingsView 已在前两任务移走)。Read 整个当前 MainViews.swift 确认剩余内容。

- [ ] **Step 2: 创建 WordListView.swift**

创建 `WordClip/Views/WordListView.swift`,import 块:

```swift
import SwiftUI
import SwiftData
import WordClipKit
```

其后粘贴 MainViews.swift 里**除顶部 import 外的全部剩余内容**(WordSort + WordSelection + WordListView + WordDetailPane + DictionaryPreviewPane,含各自文档注释)。逐字保留。

> 注:MainViews 原顶部有 `UniformTypeIdentifiers` 与 `#if os(macOS) KeyboardShortcuts`;这些是 SettingsView 用的,已随 Task 2 移走。剩余三栏类型只需 SwiftUI/SwiftData/WordClipKit(依据:探查确认 WordListView/WordDetailPane 用 SwiftData+WordClipKit,WordSort/DictionaryPreviewPane 用 WordClipKit)。若构建报缺 import,按报错补。

- [ ] **Step 3: 删除 MainViews.swift**

```bash
cd /Users/seven/Works/github/wordclip && git rm WordClip/Views/MainViews.swift
```

- [ ] **Step 4: xcodegen + 构建 macOS + iOS**

Run: `cd /Users/seven/Works/github/wordclip && xcodegen generate >/dev/null 2>&1 && xcodebuild -project WordClip.xcodeproj -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -3`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild -project WordClip.xcodeproj -scheme WordClip-iOS -configuration Debug -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -2`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 运行时冒烟(macOS)**

Run:
```bash
osascript -e 'quit app "WordClip"' 2>/dev/null; sleep 1
APP="$(ls -d ~/Library/Developer/Xcode/DerivedData/WordClip-*/Build/Products/Debug/WordClip.app | head -1)"; open "$APP" && sleep 3 && (pgrep -x WordClip >/dev/null && echo "RUNNING OK" || echo "NOT RUNNING")
```
Expected: `RUNNING OK`。之后 `osascript -e 'quit app "WordClip"'`。

- [ ] **Step 6: 提交**

```bash
git add -A
git commit -m "refactor: 抽出生词本三栏到 WordListView.swift,删除 MainViews.swift"
```

---

## Self-Review

**Spec coverage:**
- SidebarView → 独立文件 → Task 1 ✓
- SettingsView → 独立文件 → Task 2 ✓
- WordListView + WordDetailPane + DictionaryPreviewPane + WordSort + WordSelection → WordListView.swift → Task 3 ✓
- 删除 MainViews.swift → Task 3 Step 3 ✓
- 不改类型内部 / 纯移动 → 各 Task「逐字保留」+ Global Constraints ✓
- 按需 import → 各 Task Step 2 明确 import 块(依据探查的实际使用)✓
- xcodegen 纳入新文件 → 各 Task 构建步含 `xcodegen generate` ✓

**Placeholder scan:** 无 TBD/TODO。行范围、import 块、命令、预期均具体。Task 2/3 有「若构建报缺 import 按报错补」的兜底——因逐字移动理论上 import 已齐,兜底仅防探查遗漏,非占位。

**顺序依赖正确性:** 每步只移动一组类型,类型始终恰好存在于一处(先加新文件、再删原处),故每步可独立编译。Task 顺序无强依赖(3 个类型组互不依赖定义位置),但按 SidebarView→SettingsView→WordListView 顺序,最后一步自然清空 MainViews 并删除——顺序合理。

**Type consistency:** 全程零类型/签名改动,纯文件位置移动。跨文件引用(ContentView→SidebarView/WordListView/SettingsView;WordClipApp→SettingsView)因同 module 不受影响。
