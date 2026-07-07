# 导入词典功能优化 — 设计文档

> 日期:2026-07-07 · 状态:已定稿待实现

## 背景与问题

设置页「词典」分区提供「导入词典…」功能(Pro),但对用户几乎没有可用信息:

- 唯一说明是一句技术味 footer:「支持 CSV(word,释义[,音标])与 ECDICT 结构的 SQLite。多本词典按顺序叠加查询,内置优先。」
- 普通用户三个疑问全无答案:①这功能干嘛的 ②文件长什么样 ③去哪里获取。
- 容易与「词包(懒人包)」混淆——一个扩充**查词释义源**,一个添加**学习词条**。

现状事实(已探查):
- 支持格式:CSV/TSV/TXT(`word,definition[,phonetic]`,逗号或制表符分隔,支持表头跳过、双引号 `""` 转义)、ECDICT 结构 SQLite(需含 `entries` 表 + `word`/`definition` 列)。
- 解析逻辑在 Kit `DictionaryImporter`(`parseCSV` 为 internal static,`CSVRow: Equatable`,可单测);App 侧 `DictionarySettingsSection` + `DictionaryStore` 管理导入/启停/删除。
- 导入是 Pro,导出免费。

## 定位判断(方向:讲清楚、体面保留)

内置 ECDICT 5 万词 + 词形还原已覆盖日常英语,**多数用户无需导入**。导入词典是给少数专业/进阶用户的能力(专业领域词库、英→其他语言释义、自制词表)。因此不做重投入(不做现成词典包、不做内置向导);优化重点在**说清用途 + 格式说明 + 词源指引**,且遵守 ARCHITECTURE「只提供用户有权使用的词库,不分发/不引流第三方商业词典」。

## 信息架构:两层

- **设置页(轻)**:一句大白话用途 + 「了解如何导入 ›」链接。
- **说明页(重)**:独立 `DictionaryImportGuideView`,复用 HelpView 的原生分区排版(`Section`/`Item`)与「通知 + sheet」唤起模式。

不把词典说明混入综合 HelpView——它太专业、篇幅长,单独成页更聚焦,也避免稀释 HelpView 的普适性。

## 说明页内容(四节)

复用 HelpView 的 `Section`/`Item`(图标 + 标题 + 正文)。

**① 这是什么(先破除混淆)**
- 图标 `character.book.closed`。正文:导入的词典**只在查词时提供额外释义**(如专业术语、其他语言),不会往生词本加词。想批量加学习词条请用「词包」。

**② 什么时候需要**
- 图标 `sparkle.magnifyingglass`。正文:内置 ECDICT 5 万词已覆盖日常英语,**大多数人无需导入**。适合:查专业领域词库(医学/法律/计算机)、需要英→其他语言释义、有自制词表的用户。

**③ 支持的格式(带可视示例)**
- CSV(图标 `text.aligncenter`):列序 word, definition, phonetic(可选)。示例块(等宽字体 + 浅底):
  ```
  word,definition,phonetic
  ephemeral,adj. 短暂的,ɪˈfem(ə)rəl
  ```
  说明:逗号或制表符分隔;首行表头可选;第三列音标可省;释义含逗号用双引号包裹。
- SQLite(图标 `cylinder.split.1x2`):需含 `entries` 表,且有 `word`、`definition` 列(ECDICT 结构),导入时直接采用。

**④ 怎么自己准备(教方法,不给链接)**
- 图标 `tablecells`。正文:用 Excel / Numbers / Google 表格填三列,「另存为 / 导出」选 CSV(UTF-8)。
- 图标 `chevron.left.forwardslash.chevron.right`。正文:进阶用户可用开源词典数据自制 SQLite——例如本 App 内置词库即来自 ECDICT(MIT 开源)。只点名这一个作示范,不放外链、不涉及商业词典。

排版:CSV 示例块用 `.font(.system(.callout, design: .monospaced))` + 浅底,让格式一目了然。

## 设置页改动(`DictionarySettingsSection.swift`)

footer 改写为(用途优先 + 入口):
> 导入词典可在查词时提供额外释义(不会往生词本加词)。多本按顺序叠加,内置优先。[了解如何导入 ›]

- 第一句点明用途 + 与词包的区别;保留「叠加/内置优先」对多词典用户有用的事实。
- 「了解如何导入 ›」用 `Button`(`.buttonStyle(.plain)` + accent 色文字)发通知,不占额外行。

## 唤起接线(沿用现有三处同款模式)

- `ContentView.swift`:新增 `Notification.Name.showDictionaryImportGuide`;在已有 sheet 群加 `.sheet(isPresented:)` + `.onReceive(...)`,与 `showHelp`/`showWordPacks` 对称。
- macOS 说明页尺寸沿用 HelpView(460×600);iOS 用 `NavigationStack` + 完成按钮,复用 HelpView 外壳结构。
- **单一入口**:仅设置页 footer 的「了解如何导入 ›」触发。不加菜单项/HelpView 跳转,避免过度曝光窄众功能。

## i18n

- 新文案全部走 `String(localized:)`,zh-Hans 默认值 + en 翻译。
- key 命名:`dictguide.what.title/body`、`dictguide.when.*`、`dictguide.csv.*`、`dictguide.sqlite.*`、`dictguide.prepare.excel.*`、`dictguide.prepare.sqlite.*`、`dictguide.title`;设置页 `settings.dict.hint`(改写)、`settings.dict.learnmore`。
- CSV 示例块中的英文单词(`ephemeral` 等)不翻译——是格式示范;仅说明性文字双语。

## 测试

- 说明页为纯静态展示 + 通知/sheet 接线,无新业务逻辑 → 不为 UI 新增单测。
- **补 `DictionaryImporter.parseCSV` 边界测试**(Kit,Swift Testing):
  - 逗号分隔基本行(两列 / 三列含音标)
  - 制表符(TSV)分隔
  - 双引号包裹 + 含逗号的释义 + `""` 转义
  - 表头跳过(`word` / `headword` / `单词`)
  - 空行跳过、字段不足(仅一列)跳过
  - 音标列缺省时 `phonetic == nil`
- 验证:两端 `xcodebuild` 通过 + 运行时冒烟(设置页 footer 唤起说明页、CSV 示例排版、页面可关闭)。

## 文档同步

- HELP.md:词典导入节补「= 扩充查词释义源,非加词」。
- README.md:「自定义词典导入」条目措辞微调,点明用途区别。
- ARCHITECTURE.md:§3.3 补「新增 App 内说明页 `DictionaryImportGuideView`」。
- PROGRESS.md:词典与查词区补说明页。

## 文件清单

- 新增:`WordClip/Views/DictionaryImportGuideView.swift`
- 新增:`WordClipKit/Tests/WordClipKitTests/DictionaryImporterTests.swift`(parseCSV 边界)
- 改:`DictionarySettingsSection.swift`、`ContentView.swift`、`Localizable.xcstrings`、HELP/README/ARCHITECTURE/PROGRESS
- 无 Kit 源码改动、无 `project.yml` 改动(新视图在已纳入的 `WordClip/Views/` 下;新测试在已纳入的测试目录下)。

## 非目标(YAGNI)

- 不做现成可下载词典包 / 内置向导。
- 不放第三方商业词源外链。
- 不改 `DictionaryImporter` 解析逻辑(仅补测试)。
- 不在 HelpView / 菜单增加额外入口。
