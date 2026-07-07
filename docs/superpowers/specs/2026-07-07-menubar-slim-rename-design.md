# 状态栏菜单精简 + 「词包」改名「懒人包」— 设计文档

> 日期:2026-07-07 · 状态:已定稿待实现

## 背景与目标

两件独立但同批的用户体验优化:

1. **全局改名**:把用户可见的「词包」统一改成「懒人包」。现状两词混用——「词包」是正式入口名(菜单、移除按钮、确认弹窗),「懒人包」只在括号注解里(如 HelpView「词包(懒人包)」)。统一为「懒人包」。
2. **状态栏菜单精简**:现有 6 项菜单中 5 项与主窗口/Dock/⌘, 重复,只「快速开关收词」有独特价值。保留状态栏图标(收词启用状态指示 + 快速开关),菜单砍到 4 块。

## 现状(已探查)

- **状态栏菜单**(`MenuBarMenuView.swift`):今日概览(灰字不可点)→ 开始复习(⌘R)→ 分隔 → 启用/停用选中收词(⌘E)→ 分隔 → 打开 WordClip(⌘O)→ 词包…→ 设置…(⌘,)→ 分隔 → 退出(⌘Q)。图标 `MenuBarIcon`,`captureEnabled` 时不透明、停用时 opacity 0.4。
- **「词包」措辞**:源码/文档共约 64 处(不含 xcstrings);xcstrings 含「词包」的 key 约十几个。用户可见 defaultValue 分布在 MainViews(移除按钮/确认/菜单入口)、MenuBarMenuView、HelpView、WordPackBrowserView 等。
- **数据层**:导入时 `WordPackDTO.name`(如「旅游娱乐」「CET-4」)存入 `WordGroup.name`——是具体包名、不含「词包」二字。分组选择器显示具体名,不受改名影响。

## A. 全局改名「词包」→「懒人包」

**改:所有用户可见文案(defaultValue + 文档)**
- 菜单入口:「词包…」→「懒人包…」(`menu.wordpacks` key 的 defaultValue,MainViews + MenuBarMenuView 两处引用同一 key)。
- 移除相关:「移除此词包」→「移除此懒人包」;「移除词包」(确认按钮)→「移除此懒人包」;移除确认标题「移除「X」词包?」→「移除「X」懒人包?」;说明「将删除该词包的 N 个单词…」→「将删除该懒人包的 N 个单词…」。
- HelpView:分区标题「词包(懒人包)」→「懒人包」;「预置词包」→「预置懒人包」及该节正文里的「词包」。
- WordPackBrowserView / ContentView 引导:标题、按钮等含「词包」的展示文案。
- 词典说明页 `DictionaryImportGuideView`:提到「用『词包』」的地方 → 「用『懒人包』」。
- 文档:HELP.md / README.md / docs/PROGRESS.md / docs/ARCHITECTURE.md 里用户向的「词包」→「懒人包」(架构文档中作为功能名的「词包」一并改;代码标识符引用如 `WordPackStore`/`WordPackRemover` 保持原样)。

**不改(避免大面积无意义重命名):**
- 代码标识符:`WordPackDTO` / `WordPackStore` / `WordPackRemover` / `WordPackCatalog` / `WordPackBrowserView` / `WordPackImporter`、通知名 `showWordPacks`、String Catalog 的 **key 名**(如 `menu.wordpacks`、`help.section.packs`、`wordlist.removePack.*`)——只改这些 key 的**值**,不改 key 本身。
- `WordGroup.name` 数据(具体包名,不含「词包」)。
- `WordGroup.kindPack` 常量值 `"pack"`、`packSlug` 等内部标识。

**i18n**:xcstrings 手动管理。改了 defaultValue 的 key 同步 zh-Hans + en 两语(英文原本多为 "Word Pack(s)" 之类;改名后 en 可保留 "Word Pack" 或统一——**en 维持既有英文表述不变**,因为「懒人包」是中文语感梗,英文 "Word Pack" 已达意;只中文改「懒人包」)。即:**中文改「懒人包」,英文不动**。

## B. 状态栏菜单精简

**精简后菜单(留 4 块):**
```
生词本 N · 待复习 N · 新词 N     (今日概览,灰字)
───
✂ 启用/停用选中收词              (⌘E)
───
打开 WordClip                    (⌘O)
退出                             (⌘Q)
```

**砍掉 3 项:**
- 开始复习(⌘R):主窗口复习页已有,概览已提示待复习数。
- 懒人包…:主窗口工具栏 + 首启引导都有入口。
- 设置…(⌘,):⌘, / Dock 右键 / 应用菜单都能开。

**保留:** 图标(`MenuBarIcon` + captureEnabled 透明度指示不动)、今日概览(瞥一眼状态)、启用/停用收词(独特价值)、打开 WordClip(主窗关闭后回主窗的直达)、退出。

**实现:** 删 `MenuBarMenuView.swift` 里「开始复习」Button + 其后 Divider、「懒人包…」Button、「设置…」Button。保留「打开 WordClip」上方那个 Divider 作为概览与操作区的分隔。`refreshStats` 与概览逻辑不动。

> 注:`menubar.review` / `menu.wordpacks` / `menubar.settings` 这几个 key 在删除按钮后于 MenuBarMenuView 不再引用,但 **`menu.wordpacks` 仍被 MainViews 工具栏引用、`menubar.settings` 仍被无——需确认**:删除后逐个 grep,只有全仓再无引用的 key 才作孤儿删除(大概率都还有别处引用,保留)。

## 测试

- 纯 UI 文案 + 菜单结构调整,无业务逻辑 → 不新增单测;Kit 仍应 70 绿。
- 验证:macOS `xcodebuild` 通过 + 冒烟——状态栏菜单只剩 4 块;主窗口工具栏/引导/移除按钮等处显示「懒人包」。
- iOS `xcodebuild` 通过(改名涉及跨平台文案)。

## 文件清单

- `WordClip/Views/MenuBarMenuView.swift`:删 3 个菜单项;「词包…」若保留则改「懒人包…」(实为删除该项)。
- `WordClip/Views/MainViews.swift`:移除按钮/确认/菜单入口的「词包」→「懒人包」defaultValue。
- `WordClip/Views/HelpView.swift`:懒人包分区文案。
- `WordClip/Views/WordPackBrowserView.swift`:引导/浏览页展示文案。
- `WordClip/Views/DictionaryImportGuideView.swift`:提到词包处。
- `WordClip/Views/ContentView.swift`:首启引导相关展示文案(若有)。
- `WordClip/Resources/Localizable.xcstrings`:改动 key 的 zh-Hans 值(en 不动);删除删按钮后确无引用的孤儿 key(逐个 grep 确认)。
- `HELP.md` / `README.md` / `docs/PROGRESS.md` / `docs/ARCHITECTURE.md`:用户向「词包」→「懒人包」。
- 无 Kit 改动、无 `project.yml` 改动。

## 非目标(YAGNI)

- 不重命名代码标识符 / 类型 / 通知名 / String Catalog key 名。
- 不改 `WordGroup` 数据或包的具体名。
- 不改英文文案(「懒人包」是中文表述;英文 "Word Pack" 保留)。
- 不移除状态栏图标(仅精简菜单)。
- 不改今日概览的展示逻辑 / refreshStats。
