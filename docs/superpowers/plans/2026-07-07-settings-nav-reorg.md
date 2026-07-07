# 设置页导航重构 + 分区重排 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把「设置」移出主导航(macOS 侧边栏 / iOS 底部 tab),改为 macOS 走 ⌘, 窗口、iOS 走生词本页齿轮 sheet;并把设置页 10 个分区按四主题块重排。

**Architecture:** 纯 SwiftUI 导航结构 + 视图排序调整,无 Kit / 业务逻辑改动。macOS 已有 `Window(id:"settings")`(⌘,)故只删侧边栏入口;iOS 删 tab 后在生词本页工具栏加齿轮 → sheet。iPad(regular)与 macOS 共用 `splitView`,故齿轮 sheet 需覆盖 iPad+iPhone 两种 iOS 形态。

**Tech Stack:** SwiftUI(多平台单一代码库,`#if os(macOS)` 分平台)· String Catalog(手动管理)。

## Global Constraints

- Swift 6,macOS 15+ / iOS 18+;所有 UI 文案走 `String(localized:)`,catalog 手动管理(改 defaultValue 需同步 catalog zh-Hans+en,删 key 需确认无引用)。
- 不改任何设置分区**内部逻辑**或文案 key(除删孤儿 `sidebar.settings`)。
- 不动 macOS 已有的 `Window(id:"settings")` 实现与 `WordClipCommands` 的 ⌘,。
- 无 Kit 改动、无 `project.yml` 改动(改动文件都在已纳入路径)。
- iOS 齿轮入口挂在 `ContentView` 的导航容器层,不进 `WordListView` 内部。
- macOS 侧边栏 `sidebarShortcuts` 按 `SidebarItem.allCases` 枚举生成 ⌘1..⌘N,项数变化自动跟随,无需改该函数。

---

## File Structure

- `WordClip/Views/ContentView.swift` — `SidebarItem` 去 `.settings`;`detailView` 去 case;iOS `tabView` 去设置 tab;iOS 生词本 `NavigationStack` 加齿轮 toolbar + sheet 状态/呈现。
- `WordClip/Views/MainViews.swift` — `SidebarView` 去「设置」行;`SettingsView` body 分区重排。
- `WordClip/Views/ShortcutCheatSheet.swift` — 「设置」快捷键从 ⌘4 改为 ⌘,。
- `WordClip/Resources/Localizable.xcstrings` — 删孤儿 `sidebar.settings`。
- `HELP.md` — iOS 设置入口 + macOS ⌘1–⌘3 / ⌘, 说明。

---

### Task 1: 移除主导航中的「设置」入口(macOS 侧边栏 + iOS tab)+ iOS 齿轮 sheet

一个任务:导航结构调整必须一次做完才有可用交付(删了旧入口就得同时给 iOS 新入口,否则 iOS 无法打开设置)。

**Files:**
- Modify: `WordClip/Views/ContentView.swift`
- Modify: `WordClip/Views/MainViews.swift`(仅 `SidebarView`,不含 SettingsView 重排——重排在 Task 2)

**Interfaces:**
- Consumes: 现有 `SettingsView`(无参)、`SidebarView(selection:)`、`ContentView` 的 `splitView`/`tabView`/`detailView`。
- Produces: `SidebarItem` 变为 `{ allWords, review, stats }`(去掉 `.settings`);iOS 新增设置 sheet 入口。

- [ ] **Step 1: ContentView — SidebarItem 去掉 .settings**

`WordClip/Views/ContentView.swift`,把:

```swift
enum SidebarItem: Hashable, CaseIterable {
    case allWords
    case review
    case stats
    case settings
}
```

改为:

```swift
enum SidebarItem: Hashable, CaseIterable {
    case allWords
    case review
    case stats
}
```

- [ ] **Step 2: ContentView — detailView 去掉 .settings case + 加 iOS 设置 sheet 状态**

在 `ContentView` 的 `@State` 声明区(`showingDictImportGuide` 那行附近)加一个 iOS 设置 sheet 状态:

```swift
    @State private var showingSettings = false   // iOS：从生词本页齿轮打开设置
```

把 `detailView(for:)`:

```swift
    @ViewBuilder
    private func detailView(for item: SidebarItem) -> some View {
        switch item {
        case .allWords: WordListView()
        case .review: StudyView()
        case .stats: StatsView()
        case .settings: SettingsView()
        }
    }
```

改为(去掉 `.settings` case):

```swift
    @ViewBuilder
    private func detailView(for item: SidebarItem) -> some View {
        switch item {
        case .allWords: WordListView()
        case .review: StudyView()
        case .stats: StatsView()
        }
    }
```

- [ ] **Step 3: ContentView — iOS tabView 去掉设置 tab**

把 `tabView` 里的设置 tab 整段删除:

```swift
            NavigationStack { SettingsView() }
                .tabItem {
                    Label(String(localized: "tab.settings", defaultValue: "设置"), systemImage: "gearshape")
                }
```

删除后 `tabView` 只剩 生词本 / 复习 / 统计 三个 `NavigationStack`。

- [ ] **Step 4: ContentView — iOS 生词本页加齿轮 toolbar + sheet**

iOS 上设置入口要覆盖 iPad(splitView)与 iPhone(tabView)。做法:给 iOS 的生词本 `NavigationStack` 内容套一个齿轮 toolbar。**iPad 走 splitView 的 detail、iPhone 走 tabView**,两处生词本渲染点不同,故用一个共享 modifier 给「生词本」视图加齿轮。最简做法:在 iOS 分支,把设置 sheet 挂到 `content` 外层(body 链上),并在 iPhone tabView 的生词本 `NavigationStack` + iPad splitView 的 detail `NavigationStack` 各加一个齿轮 toolbar 按钮,都翻 `showingSettings`。

为避免两处重复,新增一个私有 `@ViewBuilder` 修饰函数。在 `ContentView` 里加:

```swift
    #if os(iOS)
    /// iOS 设置入口:生词本页导航栏右上角齿轮 → sheet。
    @ViewBuilder
    private func settingsToolbar<Content: View>(_ content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Label(String(localized: "tab.settings", defaultValue: "设置"),
                          systemImage: "gearshape")
                }
            }
        }
    }
    #endif
```

在 iPhone `tabView` 的生词本 `NavigationStack` 上应用(仅生词本那一个):

```swift
            NavigationStack { WordListView() }
                .modifier(SettingsToolbarModifier(show: $showingSettings))
                .tabItem {
                    Label(String(localized: "tab.wordlist", defaultValue: "生词本"), systemImage: "books.vertical")
                }
```

> 注:`@ViewBuilder` 私有函数不能作为 `.modifier`。改用一个 `ViewModifier` 更干净。删掉上面的 `settingsToolbar` 函数写法,改为在文件内(ContentView 之外或之内均可,建议紧邻 ContentView)定义:

```swift
#if os(iOS)
/// iOS：给承载视图的导航栏右上角加设置齿轮,点开设置 sheet。
private struct SettingsToolbarModifier: ViewModifier {
    @Binding var show: Bool
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    show = true
                } label: {
                    Label(String(localized: "tab.settings", defaultValue: "设置"),
                          systemImage: "gearshape")
                }
            }
        }
    }
}
#endif
```

iPhone `tabView` 生词本:

```swift
            NavigationStack {
                WordListView()
                    .modifier(SettingsToolbarModifier(show: $showingSettings))
            }
                .tabItem {
                    Label(String(localized: "tab.wordlist", defaultValue: "生词本"), systemImage: "books.vertical")
                }
```

iPad splitView 的 detail:仅当显示生词本时加齿轮。把 `splitView` 的 detail 改为:

```swift
        } detail: {
            NavigationStack {
                detailView(for: selection ?? .allWords)
                    #if os(iOS)
                    .modifier(SettingsToolbarModifier(show: $showingSettings))
                    #endif
            }
        }
```

> 说明:iPad 上任一主页面(生词本/复习/统计)导航栏都会出现齿轮——可接受(设置是全局功能,任意页可进)。iPhone 只在生词本 tab 出现齿轮,其余 tab 不放,避免每个 tab 都挂。

- [ ] **Step 5: ContentView — 挂 iOS 设置 sheet**

在 body 的 sheet 群(iOS 也生效的位置,如 `.sheet(isPresented: $showingHelp)` 附近)加:

```swift
            #if os(iOS)
            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    SettingsView()
                        .navigationTitle(String(localized: "tab.settings", defaultValue: "设置"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button(String(localized: "help.done", defaultValue: "完成")) {
                                    showingSettings = false
                                }
                            }
                        }
                }
            }
            #endif
```

> 复用现有 `help.done`(「完成」/Done)key。`SettingsView` 已有 `.navigationTitle`,外层再设一次不冲突(sheet 内 NavigationStack 生效)。

- [ ] **Step 6: MainViews — SidebarView 去掉「设置」行**

`WordClip/Views/MainViews.swift` 的 `SidebarView`,删除:

```swift
            Label(String(localized: "sidebar.settings", defaultValue: "设置"), systemImage: "gearshape")
                .tag(SidebarItem.settings)
```

删除后 `SidebarView` 只剩 生词本 / 复习 / 统计 三行。

- [ ] **Step 7: 构建 macOS**

Run: `cd /Users/seven/Works/github/wordclip && xcodegen generate >/dev/null 2>&1 && xcodebuild -project WordClip.xcodeproj -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: 构建 iOS**

Run: `xcodebuild -project WordClip.xcodeproj -scheme WordClip-iOS -configuration Debug -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: 运行时冒烟(macOS)**

Run:
```bash
APP="$(ls -d ~/Library/Developer/Xcode/DerivedData/WordClip-*/Build/Products/Debug/WordClip.app | head -1)"; open "$APP" && sleep 3 && (pgrep -x WordClip >/dev/null && echo "RUNNING OK" || echo "NOT RUNNING")
```
Expected: `RUNNING OK`。手动确认:侧边栏只剩 3 项;⌘, 打开设置窗口正常。之后 `osascript -e 'quit app "WordClip"'`。

- [ ] **Step 10: 提交**

```bash
git add WordClip/Views/ContentView.swift WordClip/Views/MainViews.swift
git commit -m "feat: 设置移出主导航(macOS 侧边栏去项/iOS tab 改齿轮 sheet)"
```

---

### Task 2: 设置页分区按四主题块重排

**Files:**
- Modify: `WordClip/Views/MainViews.swift`(`SettingsView` body 内 `Section` 顺序)

**Interfaces:**
- Consumes: `SettingsView` 现有所有 `Section`(选中收词/OCR/通用/学习/提醒/词典/Pro/同步/数据/帮助/调试)与 `DictionarySettingsSection()`。
- Produces: 重排后的 body。不改任何分区内部或 key。

- [ ] **Step 1: 重排 SettingsView body 的 Section 顺序**

目标顺序(块内保持各分区独立):

1. **收词(macOS 特有)**:选中收词 → OCR 收词
2. **学习(跨平台)**:学习(每轮词数)→ 复习提醒 → 词典(`DictionarySettingsSection()`)
3. **数据与账户**:Pro 升级 → iCloud 同步 → 数据备份
4. **通用与关于**:通用(登录自启,macOS 特有)→ 使用帮助 →(DEBUG:调试)

操作:在 `SettingsView` 的 `Form { ... }` 内,把现有各 `Section` 整段按上述顺序重新排列。**逐字保留每个 Section 的内容与 `#if os(macOS)` 包裹**,仅移动它们的位置。具体:

- 把「通用」Section(`settings.section.general`,含 `#if os(macOS)` 收尾的 `#endif`)从原位置(OCR 之后)移动到「使用帮助」之前。
- 把「词典」`DictionarySettingsSection()` 从原位置(提醒之后、Pro 之前)移到「复习提醒」Section 之后(它本就在提醒之后,确认紧邻)。
- 确保最终顺序为:选中收词(macOS)、OCR(macOS)、学习、提醒、词典、Pro、同步、数据、通用(macOS)、帮助、调试(DEBUG)。

> 关键:`#if os(macOS)` / `#endif` 的配对必须随 Section 整体移动,不能拆散。收词两个 Section 在最前的 `#if os(macOS)` 块内;通用 Section 单独需要自己的 `#if os(macOS)`/`#endif` 包裹(移动后它不再紧邻收词块,故必须带上自己的条件编译)。

- [ ] **Step 2: 构建 macOS**

Run: `cd /Users/seven/Works/github/wordclip && xcodebuild -project WordClip.xcodeproj -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 构建 iOS**

Run: `xcodebuild -project WordClip.xcodeproj -scheme WordClip-iOS -configuration Debug -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`(验证 iOS 侧 macOS 特有分区被正确条件编译排除,不漏 `#endif`)

- [ ] **Step 4: 运行时冒烟(macOS)**

Run:
```bash
APP="$(ls -d ~/Library/Developer/Xcode/DerivedData/WordClip-*/Build/Products/Debug/WordClip.app | head -1)"; open "$APP" && sleep 3 && (pgrep -x WordClip >/dev/null && echo "RUNNING OK" || echo "NOT RUNNING")
```
Expected: `RUNNING OK`。手动确认 ⌘, 设置窗口分区顺序为:选中收词 → OCR → 学习 → 提醒 → 词典 → Pro → 同步 → 数据 → 通用 → 帮助 →(Debug)。之后退出 app。

- [ ] **Step 5: 提交**

```bash
git add WordClip/Views/MainViews.swift
git commit -m "feat: 设置页分区按四主题块重排(收词/学习/数据与账户/通用与关于)"
```

---

### Task 3: 更新快捷键速查表 + 删孤儿 key + 文档同步

收尾:清理导航改动的连带引用与文档。

**Files:**
- Modify: `WordClip/Views/ShortcutCheatSheet.swift`
- Modify: `WordClip/Resources/Localizable.xcstrings`
- Modify: `HELP.md`

**Interfaces:**
- Consumes: Task 1 的导航结构(设置不再是 ⌘4)。
- Produces: 无。

- [ ] **Step 1: ShortcutCheatSheet — 设置改为 ⌘,**

`WordClip/Views/ShortcutCheatSheet.swift` 导航组,把:

```swift
                Item(desc: String(localized: "sidebar.settings", defaultValue: "设置"), keys: ["⌘4"]),
```

改为(macOS 设置走 ⌘,;key 从 `sidebar.settings` 换成仍存在的 `tab.settings`):

```swift
                Item(desc: String(localized: "tab.settings", defaultValue: "设置"), keys: ["⌘,"]),
```

- [ ] **Step 2: 确认 sidebar.settings 已无引用**

Run: `grep -rn "sidebar.settings" WordClip/ | grep -v "Localizable.xcstrings"`
Expected: 无输出(仅 catalog 里还有该 key,源码已无引用)。若仍有源码引用,先改掉再继续。

- [ ] **Step 3: 删除孤儿 key sidebar.settings**

用 Python 删 catalog 里的 `sidebar.settings`(手动管理,精确删键):

```bash
cd /Users/seven/Works/github/wordclip && python3 - <<'PY'
import json
p='WordClip/Resources/Localizable.xcstrings'
d=json.load(open(p))
removed = d['strings'].pop('sidebar.settings', None)
json.dump(d, open(p,'w'), ensure_ascii=False, indent=2)
json.load(open(p))  # 验证合法
print("removed sidebar.settings:", removed is not None)
PY
```
Expected: `removed sidebar.settings: True`

- [ ] **Step 4: HELP.md — 更新键盘快捷键表 + iOS 设置入口**

在 `HELP.md` 找到键盘快捷键表,把:

```
| `⌘1` / `⌘2` / `⌘3` / `⌘4` | 切换 生词本 / 复习 / 统计 / 设置 |
```

改为:

```
| `⌘1` / `⌘2` / `⌘3` | 切换 生词本 / 复习 / 统计 |
| `⌘,` | 打开设置 |
```

并在 iOS/iPadOS 用法段落补一句设置入口(找到 iOS 用法列表,追加):

```
- **设置**:在生词本页右上角点齿轮图标打开
```

> 若 HELP.md 快捷键表的实际文本与上面不完全一致,以「去掉 ⌘4=设置、新增 ⌘,=设置」为准调整。

- [ ] **Step 5: 构建确认 catalog 合法 + 无遗漏引用**

Run: `cd /Users/seven/Works/github/wordclip && xcodebuild -project WordClip.xcodeproj -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 提交**

```bash
git add WordClip/Views/ShortcutCheatSheet.swift WordClip/Resources/Localizable.xcstrings HELP.md
git commit -m "chore: 速查表设置改 ⌘,、删孤儿 sidebar.settings、HELP 同步导航变更"
```

---

## Self-Review

**Spec coverage:**
- macOS 侧边栏去设置项 → Task 1 Step 1/6 ✓
- macOS 保留 ⌘, 窗口(不动) → 未改动,符合 ✓
- iOS 去 tab + 齿轮 sheet → Task 1 Step 3/4/5 ✓
- ⌘1–⌘3 自动跟随 → SidebarItem 减项,sidebarShortcuts 无需改 ✓
- 设置页四主题块重排 → Task 2 ✓
- 删孤儿 sidebar.settings → Task 3 Step 3 ✓
- 文档同步(HELP 快捷键 + iOS 入口)→ Task 3 Step 4 ✓
- 速查表 ⌘4→⌘,(spec 未列但属连带,已补)→ Task 3 Step 1 ✓
- MenuBar「设置…」已用 openWindow(id:settings),无需改(已确认)✓

**Placeholder scan:** 无 TBD/TODO;所有步骤含实际代码/命令/预期。Task 3 Step 4 对 HELP.md 文本给了「以…为准」的兜底判断,非模糊占位。

**Type consistency:** `SettingsToolbarModifier(show:)` 在 Task 1 Step 4 定义并在 iPhone/iPad 两处使用,签名一致;`showingSettings` @State(Step 2 定义 → Step 4/5 使用)一致;`tab.settings` key 全程保留复用;`help.done` 复用现有 key。

**Notes:** iPad 上三个主页面导航栏都会出现齿轮(spec 已接受「设置是全局功能,任意页可进」);iPhone 仅生词本 tab 有齿轮。
