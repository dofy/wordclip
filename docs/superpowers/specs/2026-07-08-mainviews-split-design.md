# MainViews.swift 按职责拆分 — 设计文档

> 日期:2026-07-08 · 状态:已定稿待实现

## 背景与目标

`WordClip/Views/MainViews.swift` 已达 **1410 行**(第二大文件才 399 行),塞了 7 个不相关的顶层类型,是个"杂物抽屉"。文件过大导致可维护性差、编辑易出错(本会话已有踩坑)。按职责拆成 4 个聚焦文件。

**纯结构重构:只移动顶层类型到新文件,不改任何类型的内部实现、不改功能。**

## 现状(已探查)

MainViews.swift 的 7 个顶层类型(行范围):
- `SidebarView`(10–27)—— 被 ContentView 引用
- `WordSort`(28–72)—— 仅 WordListView 用
- `WordSelection`(73–80)—— 仅 WordListView 用
- `WordListView`(81–820,~740 行)—— 被 ContentView 引用
- `WordDetailPane`(821–1011)—— 仅 WordListView 用
- `DictionaryPreviewPane`(1012–1079)—— 仅 WordListView 用
- `SettingsView`(1080–1410)—— 被 ContentView + WordClipApp 引用

**关键事实**:全部同一 module(App target),跨文件引用零成本(Swift 同 module 内自由访问),拆分对引用无影响。WordListView 内部的私有视图/方法高度耦合(共享 `selectedItem`/`displayWords`/`searchText` 等 @State),**不拆内部**——抽出去要传大量 binding、得不偿失,740 行是复杂视图的合理体量。

## 拆分方案(4 文件)

| 文件 | 装什么 | 约行数 |
|------|--------|--------|
| `WordClip/Views/SidebarView.swift` | `SidebarView` | ~18 |
| `WordClip/Views/WordListView.swift` | `WordSort` + `WordSelection` + `WordListView` + `WordDetailPane` + `DictionaryPreviewPane`(生词本三栏 + 其专用枚举,紧密协作,留一起) | ~990 |
| `WordClip/Views/SettingsView.swift` | `SettingsView` | ~330 |
| `WordClip/Views/MainViews.swift` | **删除**(内容全部迁出) | 0 |

**归类理由**:
- `WordSort`/`WordSelection` 只被 WordListView 使用 → 跟 WordListView 走。
- `WordDetailPane`/`DictionaryPreviewPane` 是生词本三栏布局(列表→详情→词典预览)的协作组件,与 WordListView 同源 → 留一起。
- `SidebarView`/`SettingsView` 职责独立 → 各自成文件。

## 实现要点

- 每个新文件按需带上 import:`SwiftUI` 必备;`SwiftData`(用到 @Query/modelContext 的)、`WordClipKit`(用到模型/服务的)、`UniformTypeIdentifiers`(SettingsView 的 fileImporter/fileExporter 用)、`KeyboardShortcuts`(SettingsView 的快捷键录制用)按各文件实际使用添加。
- 逐类型**整段剪切**,不改类型内部一个字符。
- 删除空的 MainViews.swift。
- 新文件在已纳入 XcodeGen folder 引用的 `WordClip/Views/` 下,**无需改 project.yml**;但需 `xcodegen generate` 让新文件进入编译目标。

## 测试

- 纯结构重构,无逻辑改动 → 不新增单测;Kit 仍应 70 绿。
- 验证:`xcodegen generate` 后 macOS + iOS 均 `xcodebuild` 通过(证明类型迁移后引用完整、import 齐全);运行时冒烟(app 启动、生词本/设置/侧边栏正常)。

## 文件清单

- 新增:`WordClip/Views/SidebarView.swift`、`WordClip/Views/WordListView.swift`、`WordClip/Views/SettingsView.swift`
- 删除:`WordClip/Views/MainViews.swift`
- 无 Kit 改动、无 project.yml 改动(folder 引用自动纳入)、无文案/文档改动。

## 非目标(YAGNI)

- 不拆 WordListView 内部(私有视图/方法保持不动)。
- 不改任何类型的实现、签名、文案、key。
- 不重命名类型。
- 不动其它文件。
