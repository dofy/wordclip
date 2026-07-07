# 设置页导航重构 + 分区重排 — 设计文档

> 日期:2026-07-07 · 状态:已定稿待实现

## 背景与目标

- **设置从主导航移除**:去掉侧边栏(macOS)/ 底部 tab(iOS)里的「设置」项,设置只通过菜单 + 快捷键(macOS)/ 工具栏齿轮(iOS)打开。让主导航聚焦「生词本 / 复习 / 统计」三件核心事。
- **设置页内容重排**:现有 10 个分区顺序随意,按主题聚合重排成四大块,一页到底(不分 tab、不加两级标题)。

## 现状(已探查)

- **macOS 已有独立设置窗口**:`WordClipApp.swift` 的 `Window(id:"settings")`,由 ⌘,(`WordClipCommands` 的 `.appSettings`)/ 应用菜单「设置…」打开。所以 macOS 设置目前有**两个入口**:侧边栏第 4 项 + ⌘, 窗口。本次删侧边栏入口、保留 ⌘, 窗口。
- **iOS 设置是底部 TabView 第 4 个 tab**。iOS 无菜单栏 / ⌘, 概念,删 tab 后需新入口。
- `SidebarItem` enum(`allWords/review/stats/settings`);`sidebarShortcuts` 按 `allCases` 枚举生成 ⌘1–⌘4(无硬编码数字,自动跟随项数)。
- `SettingsView`(MainViews.swift)是单个 `Form`,分区顺序:选中收词(macOS)→ OCR 收词(macOS)→ 通用(macOS)→ 学习 → 提醒 → 词典 → Pro → 同步 → 数据 → 帮助 → 调试(DEBUG)。

## 导航结构调整

**macOS:**
- `SidebarItem` 去掉 `.settings`;`SidebarView` 去掉「设置」行 → 侧边栏剩 生词本/复习/统计。
- `detailView(for:)` 去掉 `.settings` case。
- ⌘1–⌘3 自动对应三项(`sidebarShortcuts` 无需改,按 allCases 跟随)。
- 设置仍走已有的 `Window(id:"settings")`(⌘, / 菜单「设置…」),不改。
- 净效果:主窗口不再含设置页,设置回归 macOS 原生 ⌘, 窗口。

**iOS:**
- `tabView` 去掉「设置」tab → 底部剩 生词本/复习/统计。
- iOS 生词本页(主页)的 `NavigationStack` 顶部工具栏右上加 ⚙️ 齿轮按钮 → sheet 弹 `SettingsView`(NavigationStack + 「完成」,与 HelpView iOS 外壳同款)。
- 齿轮入口挂在 `ContentView` 的 iOS tab 容器层(生词本那个 `NavigationStack` 的 `.toolbar`),不放进 `WordListView` 内部——设置是全局功能,不由 WordListView 承担。
- 齿轮无障碍标签复用 `tab.settings`(「设置」)。

**共通:** `SettingsView` 不拆窗口,仍是一个 Form;macOS 装进设置 Window,iOS 装进 sheet。

## 设置页分区重排(四主题块,一页到底)

块内分区保持独立(不合并),仅重排顺序 + 靠拢,靠各自 header 分隔。macOS 特有分区仍用 `#if os(macOS)` 包住。

**① 收词(macOS 特有,最前)**
- 选中收词
- OCR 收词

**② 学习(跨平台)**
- 学习(每轮学习词数)
- 复习提醒
- 词典(`DictionarySettingsSection`)

**③ 数据与账户**
- Pro 升级
- iCloud 同步
- 数据备份(导入/导出)

**④ 通用与关于(低频,最后)**
- 通用(登录时自动启动,macOS 特有)
- 使用帮助
- 调试(模拟 Pro,仅 DEBUG)

**iOS 实际可见顺序**(收词/通用是 macOS 特有):学习 → 提醒 → 词典 → Pro → 同步 → 数据 → 帮助 →(DEBUG:调试)。

**排序理由:** 收词是 macOS 核心入口放最前;词典服务查词/复习故归学习块;Pro/同步/备份都涉付费与跨设备故聚为数据与账户;自启动/帮助/调试低频垫底。

**实现方式:** 仅调整 `SettingsView` body 里 `Section` 的书写顺序,不改分区内部逻辑、不改 key。

**YAGNI:** 不加块级两级标题——SwiftUI Form 无原生两级分组,自定义视图属过度设计;分区顺序 + 各自 header 已足够清晰,保持原生观感。

## i18n

- 无新增用户文案。iOS 齿轮无障碍标签复用 `tab.settings`。
- `tab.settings` 保留(iOS 齿轮 + 设置页标题用);`sidebar.settings` 变孤儿,删除(catalog 手动管理,一并清)。

## 测试

- 纯 UI 结构调整,无新业务逻辑 → 不新增单测;Kit 仍应 70 绿。
- 验证:
  - macOS `xcodebuild` 通过 + 冒烟:侧边栏仅 3 项、⌘1–⌘3 切换、⌘, 开设置窗口、设置页新顺序。
  - iOS `xcodebuild` 通过 + 冒烟:底部 3 tab、生词本页右上齿轮 → 弹设置、设置页新顺序。

## 文档同步

- **HELP.md**:iOS 用法补「设置从生词本页右上角齿轮打开」;macOS 键盘快捷键表 `⌘1–⌘4` → `⌘1–⌘3`,设置走 `⌘,`。
- **README.md**:若涉导航结构描述则微调(大概率不涉及)。
- **ARCHITECTURE.md / PROGRESS.md**:导航层级描述处补「设置不占主导航,macOS 走 ⌘, 窗口 / iOS 走齿轮 sheet」。

## 文件清单

- `WordClip/Views/ContentView.swift`:`SidebarItem` 去 `.settings`;`detailView` 去 case;iOS `tabView` 去设置 tab;iOS 生词本 `NavigationStack` 加齿轮 `.toolbar` + sheet 状态与呈现。
- `WordClip/Views/MainViews.swift`:`SidebarView` 去「设置」行;`SettingsView` body 分区重排。
- `WordClip/Resources/Localizable.xcstrings`:删 `sidebar.settings` 孤儿 key。
- `HELP.md`(+ 视情况 README/ARCHITECTURE/PROGRESS)。
- 无 Kit 改动、无 `project.yml` 改动。

## 非目标(YAGNI)

- 不把设置拆成多 tab / 多窗口。
- 不加块级两级标题。
- 不改任何分区内部逻辑或文案 key(除删孤儿 `sidebar.settings`)。
- 不动 macOS 已有的 ⌘, 设置窗口实现。
