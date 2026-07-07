# 导入词典功能优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让「导入词典」功能对用户说清用途,新增独立说明页(用途/何时需要/格式示例/怎么准备),并补 parseCSV 边界测试。

**Architecture:** 两层信息架构——设置页 footer 精简为一句用途 + 「了解如何导入」链接;独立 `DictionaryImportGuideView` 复用 HelpView 的原生分区排版与「通知 + sheet」唤起模式。不改导入解析逻辑,仅补测试。

**Tech Stack:** SwiftUI(多平台单一代码库)· SwiftData · WordClipKit(Swift Package)· Swift Testing(Kit 单测,`swift test`)· String Catalog(i18n)。

## Global Constraints

- Swift 6,macOS 15+ / iOS 18+;所有 UI 文案走 `String(localized:)`,提供 zh-Hans 默认值 + en 翻译。
- Kit 测试用 Swift Testing(`import Testing` / `@Test` / `#expect` / `@Suite`),从 `WordClipKit/` 跑 `swift test`,不用 XCTest。
- 遵守 ARCHITECTURE:词源指引只教「怎么做」,不放第三方商业词典外链、不分发商业词库;只可点名 ECDICT(MIT,内置来源)作示范。
- 不改 `DictionaryImporter` 解析逻辑(仅补测试);不加 HelpView / 菜单额外入口(说明页仅从设置页 footer 唤起)。
- 新视图落在 `WordClip/Views/`、新测试落在 `WordClipKit/Tests/WordClipKitTests/`,均在已纳入路径,无需改 `project.yml`。CSV 示例块中的英文单词不翻译。
- macOS 说明页尺寸 460×600,与 HelpView 一致;iOS 用 `NavigationStack` + 「完成」按钮。

---

## File Structure

- `WordClipKit/Tests/WordClipKitTests/DictionaryImporterTests.swift`(新增)——parseCSV 边界测试。
- `WordClip/Views/DictionaryImportGuideView.swift`(新增)——说明页,`Section`/`Item` 静态内容驱动,复用 HelpView 排版。
- `WordClip/Views/ContentView.swift`(改)——新增 `.showDictionaryImportGuide` 通知 + sheet 接线。
- `WordClip/Views/DictionarySettingsSection.swift`(改)——footer 改写 + 「了解如何导入 ›」按钮。
- `HELP.md` / `README.md` / `docs/ARCHITECTURE.md` / `docs/PROGRESS.md`(改)——文档同步。

---

### Task 1: parseCSV 边界测试

给已存在的 `DictionaryImporter.parseCSV` 补边界测试(仅测试,不改实现)。这是独立可交付单元:一个新测试文件,`swift test` 通过。

**Files:**
- Test: `WordClipKit/Tests/WordClipKitTests/DictionaryImporterTests.swift`(新增)

**Interfaces:**
- Consumes: `DictionaryImporter.parseCSV(_ raw: String) -> [DictionaryImporter.CSVRow]`(internal static);`DictionaryImporter.CSVRow`(`Equatable`,字段 `word: String`、`definition: String`、`phonetic: String?`)。均经 `@testable import WordClipKit` 访问。
- Produces: 无(纯测试)。

- [ ] **Step 1: 写测试文件**

创建 `WordClipKit/Tests/WordClipKitTests/DictionaryImporterTests.swift`:

```swift
import Testing
@testable import WordClipKit

@Suite("DictionaryImporter.parseCSV")
struct DictionaryImporterParseCSVTests {

    typealias Row = DictionaryImporter.CSVRow

    @Test("逗号分隔:两列(无音标)")
    func commaTwoColumns() {
        let rows = DictionaryImporter.parseCSV("apple,苹果")
        #expect(rows == [Row(word: "apple", definition: "苹果", phonetic: nil)])
    }

    @Test("逗号分隔:三列(含音标)")
    func commaThreeColumns() {
        let rows = DictionaryImporter.parseCSV("ephemeral,adj. 短暂的,ɪˈfem(ə)rəl")
        #expect(rows == [Row(word: "ephemeral", definition: "adj. 短暂的", phonetic: "ɪˈfem(ə)rəl")])
    }

    @Test("制表符分隔(TSV)")
    func tabSeparated() {
        let rows = DictionaryImporter.parseCSV("apple\t苹果\tˈæpl")
        #expect(rows == [Row(word: "apple", definition: "苹果", phonetic: "ˈæpl")])
    }

    @Test("双引号包裹 + 含逗号的释义")
    func quotedCommaInDefinition() {
        let rows = DictionaryImporter.parseCSV("run,\"v. 跑, 奔跑\"")
        #expect(rows == [Row(word: "run", definition: "v. 跑, 奔跑", phonetic: nil)])
    }

    @Test("双引号 \"\" 转义")
    func escapedQuotes() {
        let rows = DictionaryImporter.parseCSV("quote,\"她说\"\"你好\"\"\"")
        #expect(rows == [Row(word: "quote", definition: "她说\"你好\"", phonetic: nil)])
    }

    @Test("首行表头跳过:word / headword / 单词")
    func skipsHeader() {
        #expect(DictionaryImporter.parseCSV("word,definition\napple,苹果")
                == [Row(word: "apple", definition: "苹果", phonetic: nil)])
        #expect(DictionaryImporter.parseCSV("headword,def\napple,苹果")
                == [Row(word: "apple", definition: "苹果", phonetic: nil)])
        #expect(DictionaryImporter.parseCSV("单词,释义\napple,苹果")
                == [Row(word: "apple", definition: "苹果", phonetic: nil)])
    }

    @Test("空行跳过")
    func skipsEmptyLines() {
        let rows = DictionaryImporter.parseCSV("apple,苹果\n\n\nbanana,香蕉")
        #expect(rows == [
            Row(word: "apple", definition: "苹果", phonetic: nil),
            Row(word: "banana", definition: "香蕉", phonetic: nil),
        ])
    }

    @Test("字段不足(仅一列)跳过")
    func skipsSingleField() {
        let rows = DictionaryImporter.parseCSV("apple\nbanana,香蕉")
        #expect(rows == [Row(word: "banana", definition: "香蕉", phonetic: nil)])
    }

    @Test("音标列为空 → phonetic == nil")
    func emptyPhoneticIsNil() {
        let rows = DictionaryImporter.parseCSV("apple,苹果,")
        #expect(rows == [Row(word: "apple", definition: "苹果", phonetic: nil)])
    }
}
```

- [ ] **Step 2: 跑测试,确认通过**

Run: `cd WordClipKit && swift test --filter DictionaryImporter`
Expected: PASS,新增 9 个测试全绿。

> 注:这些测试针对已存在的实现,预期直接通过(验证行为并留回归背书)。若某条失败,说明我对现有解析行为的理解有误——停下,读 `DictionaryImporter.parseCSV` 核对真实行为后调整**测试**(不是改实现,除非发现真实 bug 再单独提)。

- [ ] **Step 3: 跑全量 Kit 测试,确认无回归**

Run: `cd WordClipKit && swift test`
Expected: PASS,总数从 61 → 70。

- [ ] **Step 4: 提交**

```bash
git add WordClipKit/Tests/WordClipKitTests/DictionaryImporterTests.swift
git commit -m "test: 补 DictionaryImporter.parseCSV 边界测试(9 条)"
```

---

### Task 2: 说明页 DictionaryImportGuideView

新增说明页视图,静态内容驱动,复用 HelpView 的 `Section`/`Item` 排版与 macOS/iOS 外壳。此任务只创建视图文件(尚未接线),以能编译为交付标准。

**Files:**
- Create: `WordClip/Views/DictionaryImportGuideView.swift`

**Interfaces:**
- Consumes: 无(自包含静态视图,`@Environment(\.dismiss)`)。
- Produces: `struct DictionaryImportGuideView: View`(无参数初始化 `DictionaryImportGuideView()`),供 Task 3 在 ContentView 的 sheet 中实例化。

- [ ] **Step 1: 写视图文件**

创建 `WordClip/Views/DictionaryImportGuideView.swift`。结构镜像 `HelpView`(macOS 自绘标题栏 + 460×600;iOS `NavigationStack` + 完成按钮),内容为四节 `Section`。CSV 示例用等宽字体 + 浅底块。

```swift
import SwiftUI

/// 「导入词典」功能说明页。仅从设置页词典分区 footer 的「了解如何导入」唤起。
/// 静态内容驱动,复用 HelpView 的原生分区排版(SwiftUI 不渲染 markdown 表格)。
struct DictionaryImportGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            titleBar
            Divider()
            scrollBody
        }
        .frame(width: 460, height: 600)
        #else
        NavigationStack {
            scrollBody
                .navigationTitle(String(localized: "dictguide.title", defaultValue: "如何导入词典"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "help.done", defaultValue: "完成")) { dismiss() }
                    }
                }
        }
        .presentationDetents([.large])
        #endif
    }

    #if os(macOS)
    private var titleBar: some View {
        HStack {
            Label(String(localized: "dictguide.title", defaultValue: "如何导入词典"),
                  systemImage: "character.book.closed")
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .focusable(false)
        }
        .padding(20)
    }
    #endif

    private var scrollBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // ① 这是什么
                section(String(localized: "dictguide.section.what", defaultValue: "这是什么")) {
                    item("character.book.closed",
                         String(localized: "dictguide.what.title", defaultValue: "扩充查词的释义来源"),
                         String(localized: "dictguide.what.body",
                                defaultValue: "导入的词典只在你查词时提供额外释义(如专业术语、其他语言),不会往生词本加词。想批量添加学习词条,请用「词包」。"))
                }
                // ② 什么时候需要
                section(String(localized: "dictguide.section.when", defaultValue: "什么时候需要")) {
                    item("sparkle.magnifyingglass",
                         String(localized: "dictguide.when.title", defaultValue: "多数人无需导入"),
                         String(localized: "dictguide.when.body",
                                defaultValue: "内置 ECDICT 5 万词已覆盖日常英语。适合这些情况:查专业领域词库(医学 / 法律 / 计算机)、需要英→其他语言释义、已有自制词表。"))
                }
                // ③ 支持的格式
                section(String(localized: "dictguide.section.format", defaultValue: "支持的格式")) {
                    VStack(alignment: .leading, spacing: 8) {
                        item("text.aligncenter",
                             String(localized: "dictguide.csv.title", defaultValue: "CSV 表格"),
                             String(localized: "dictguide.csv.body",
                                    defaultValue: "每行三列:单词、释义、音标(音标可省)。逗号或制表符分隔;首行表头可选;释义含逗号时用双引号包裹。"))
                        csvExample
                    }
                    item("cylinder.split.1x2",
                         String(localized: "dictguide.sqlite.title", defaultValue: "SQLite 词库"),
                         String(localized: "dictguide.sqlite.body",
                                defaultValue: "需含 entries 表,且有 word、definition 列(即 ECDICT 结构),导入时直接采用。"))
                }
                // ④ 怎么自己准备
                section(String(localized: "dictguide.section.prepare", defaultValue: "怎么自己准备")) {
                    item("tablecells",
                         String(localized: "dictguide.prepare.excel.title", defaultValue: "用表格软件做 CSV"),
                         String(localized: "dictguide.prepare.excel.body",
                                defaultValue: "在 Excel / Numbers / Google 表格里填三列,「另存为 / 导出」时选 CSV(UTF-8)即可。"))
                    item("chevron.left.forwardslash.chevron.right",
                         String(localized: "dictguide.prepare.sqlite.title", defaultValue: "进阶:自制 SQLite"),
                         String(localized: "dictguide.prepare.sqlite.body",
                                defaultValue: "可用开源词典数据自制。例如本 App 内置词库即来自 ECDICT(MIT 开源)。"))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        #if os(macOS)
        .onExitCommand { dismiss() }
        #endif
    }

    /// CSV 示例:等宽字体 + 浅底,让格式一目了然(英文示范不翻译)。
    private var csvExample: some View {
        Text("word,definition,phonetic\nephemeral,adj. 短暂的,ɪˈfem(ə)rəl")
            .font(.system(.callout, design: .monospaced))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
            .textSelection(.enabled)
    }

    // MARK: - 排版辅助

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func item(_ symbol: String, _ heading: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 22, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(heading).font(.body.weight(.medium))
                Text(body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
```

- [ ] **Step 2: 构建 macOS,确认编译**

Run: `xcodebuild -project WordClip.xcodeproj -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 提交**

```bash
git add WordClip/Views/DictionaryImportGuideView.swift
git commit -m "feat: 新增导入词典说明页 DictionaryImportGuideView"
```

---

### Task 3: 唤起接线 + 设置页 footer 改写

在 ContentView 加通知 + sheet,把说明页接到设置页 footer 的「了解如何导入 ›」按钮。这两处必须一起改才有可用交付(通知两端要对上),故合为一个任务。

**Files:**
- Modify: `WordClip/Views/ContentView.swift`(通知定义 + 状态 + sheet + onReceive)
- Modify: `WordClip/Views/DictionarySettingsSection.swift`(footer 改写 + 按钮发通知)

**Interfaces:**
- Consumes: `DictionaryImportGuideView()`(Task 2);现有 `Notification.Name` 扩展与 ContentView 的 sheet 群模式。
- Produces: `Notification.Name.showDictionaryImportGuide`(供设置页发送)。

- [ ] **Step 1: ContentView 加通知定义**

在 `WordClip/Views/ContentView.swift` 的 `extension Notification.Name` 末尾(`showWordPacks` 之后)加:

```swift
    /// 请求显示「导入词典」说明页。
    static let showDictionaryImportGuide = Notification.Name("showDictionaryImportGuide")
```

- [ ] **Step 2: ContentView 加状态**

在 `@State private var showingWordPacks = false` 下一行加:

```swift
    @State private var showingDictImportGuide = false
```

- [ ] **Step 3: ContentView 加 sheet + onReceive**

在 `.sheet(isPresented: $showingHelp) { HelpView() }` 之后紧接着加:

```swift
            .sheet(isPresented: $showingDictImportGuide) {
                DictionaryImportGuideView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showDictionaryImportGuide)) { _ in
                showingDictImportGuide = true
            }
```

- [ ] **Step 4: 改写设置页 footer + 加按钮**

在 `WordClip/Views/DictionarySettingsSection.swift`,把现有 footer:

```swift
        } footer: {
            Text(String(localized: "settings.dict.hint",
                defaultValue: "支持 CSV（word,释义[,音标]）与 ECDICT 结构的 SQLite。多本词典按顺序叠加查询，内置优先。"))
            .foregroundStyle(.secondary)
        }
```

替换为:

```swift
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "settings.dict.hint",
                    defaultValue: "导入词典可在查词时提供额外释义（不会往生词本加词）。多本按顺序叠加，内置优先。"))
                Button(String(localized: "settings.dict.learnmore", defaultValue: "了解如何导入 ›")) {
                    NotificationCenter.default.post(name: .showDictionaryImportGuide, object: nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .focusable(false)
            }
            .foregroundStyle(.secondary)
        }
```

- [ ] **Step 5: 构建 macOS,确认编译**

Run: `xcodebuild -project WordClip.xcodeproj -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 构建 iOS,确认跨端编译**

Run: `xcodebuild -project WordClip.xcodeproj -scheme WordClip-iOS -configuration Debug -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 运行时冒烟**

Run:
```bash
APP="$(ls -d ~/Library/Developer/Xcode/DerivedData/WordClip-*/Build/Products/Debug/WordClip.app | head -1)"; open "$APP" && sleep 3 && (pgrep -x WordClip >/dev/null && echo "RUNNING OK" || echo "NOT RUNNING")
```
Expected: `RUNNING OK`。手动确认:设置 → 词典 → footer 有「了解如何导入 ›」,点击弹出说明页,CSV 示例块等宽显示,可关闭。之后 `osascript -e 'quit app "WordClip"'`。

- [ ] **Step 8: 提交**

```bash
git add WordClip/Views/ContentView.swift WordClip/Views/DictionarySettingsSection.swift
git commit -m "feat: 设置页词典 footer 说明用途 + 「了解如何导入」唤起说明页"
```

---

### Task 4: en 翻译 + 文档同步

补齐新增 key 的英文翻译,并同步四份文档。收尾任务。

**Files:**
- Modify: `WordClip/Resources/Localizable.xcstrings`(en 翻译)
- Modify: `HELP.md` / `README.md` / `docs/ARCHITECTURE.md` / `docs/PROGRESS.md`

**Interfaces:**
- Consumes: Task 2/3 引入的 `String(localized:)` key。
- Produces: 无。

- [ ] **Step 1: 确认新 key 已进 String Catalog**

先构建一次让 Xcode 把新 `String(localized:)` 抽取进 catalog(Task 2/3 的构建已完成抽取)。确认 key 存在:

Run: `grep -c "dictguide\." WordClip/Resources/Localizable.xcstrings`
Expected: ≥ 10(11 个 dictguide.* key)。若为 0,说明未抽取——重跑一次 macOS 构建。

- [ ] **Step 2: 为新 key 补 en 翻译**

编辑 `WordClip/Resources/Localizable.xcstrings`,给下列 key 各补一条 `"en"` localization(与现有条目同结构:`"en" : { "stringUnit" : { "state" : "translated", "value" : "..." } }`)。逐条英文值:

| key | en value |
|-----|----------|
| `dictguide.title` | How to Import a Dictionary |
| `dictguide.section.what` | What This Is |
| `dictguide.what.title` | Extra sources for lookups |
| `dictguide.what.body` | Imported dictionaries only add extra definitions when you look up a word (e.g. specialized terms, other languages). They do not add words to your word list — use Word Packs for that. |
| `dictguide.section.when` | When You Need It |
| `dictguide.when.title` | Most people don't need this |
| `dictguide.when.body` | The built-in ECDICT (50k words) already covers everyday English. Useful when you want a specialized dictionary (medical / legal / tech), definitions into another language, or you have your own word list. |
| `dictguide.section.format` | Supported Formats |
| `dictguide.csv.title` | CSV table |
| `dictguide.csv.body` | Three columns per row: word, definition, phonetic (phonetic optional). Comma- or tab-separated; header row optional; wrap a definition in double quotes if it contains a comma. |
| `dictguide.sqlite.title` | SQLite database |
| `dictguide.sqlite.body` | Must contain an `entries` table with `word` and `definition` columns (ECDICT structure); adopted directly on import. |
| `dictguide.section.prepare` | How to Prepare One |
| `dictguide.prepare.excel.title` | Make a CSV in a spreadsheet |
| `dictguide.prepare.excel.body` | Fill three columns in Excel / Numbers / Google Sheets, then Save As / Export as CSV (UTF-8). |
| `dictguide.prepare.sqlite.title` | Advanced: build a SQLite file |
| `dictguide.prepare.sqlite.body` | Build one from open dictionary data. For example, this app's built-in dictionary comes from ECDICT (MIT-licensed). |
| `settings.dict.hint` | Imported dictionaries add extra definitions when looking up words (they don't add words to your list). Multiple dictionaries stack in order; built-in takes priority. |
| `settings.dict.learnmore` | Learn how to import › |

> 注:`settings.dict.hint` 的中文默认值已在 Task 3 改过,这里更新它的 en 值。`help.done`(完成/Done)已存在,复用不新增。

- [ ] **Step 3: 构建确认 catalog 无语法错误**

Run: `xcodebuild -project WordClip.xcodeproj -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 同步 HELP.md**

在 `HELP.md` 词典导入相关处(「导入词库」条)补一句用途澄清。找到:

```
- **导入词库**:在新设备恢复到手动收录,按单词智能合并、不覆盖已有进度。**Pro 功能。**
```

> 注:上面这条是「备份导入」,不是词典导入。词典导入的说明在 README/设置页。在 HELP.md 的词典相关段落(搜索「导入的词典」或「自定义词典」;若无独立段落则跳过 HELP.md,词典用途已在 App 内说明页覆盖)。确认方式:

Run: `grep -n "词典" HELP.md`
若有「导入词典 / 自定义词典」条目,补一句「= 扩充查词释义源,不往生词本加词」;若 HELP.md 未单列词典导入,则不改 HELP.md(App 内说明页已覆盖),在提交信息里注明。

- [ ] **Step 5: 同步 README.md**

找到「自定义词典导入」条目:

```
- **自定义词典导入**:支持 CSV 和 ECDICT 结构的 SQLite，多本词典按优先级叠加查询，可单独启用/停用/删除/排序。
```

改为:

```
- **自定义词典导入**:扩充查词时的释义来源(非添加生词)。支持 CSV 和 ECDICT 结构的 SQLite，多本按优先级叠加，可启用/停用/删除/排序;App 内含格式说明与准备指引。
```

- [ ] **Step 6: 同步 ARCHITECTURE.md**

在 §3.3「自定义导入(本地,已实现)」条目末尾补一句:

```
新增 App 内说明页 `DictionaryImportGuideView`(用途 / 何时需要 / 格式示例 / 怎么准备),仅从设置页词典分区 footer 唤起。
```

- [ ] **Step 7: 同步 PROGRESS.md**

在「词典与查词」区的「自定义词典导入」条目末尾补:

```
;App 内「如何导入词典」说明页(`DictionaryImportGuideView`)讲清用途与格式。
```

- [ ] **Step 8: 提交**

```bash
git add WordClip/Resources/Localizable.xcstrings HELP.md README.md docs/ARCHITECTURE.md docs/PROGRESS.md
git commit -m "i18n+docs: 导入词典说明页 en 翻译 + 文档同步用途澄清"
```

---

## Self-Review

**Spec coverage:**
- 设置页精简 + 链接 → Task 3 ✓
- 独立说明页四节 → Task 2 ✓
- 唤起接线(通知+sheet)→ Task 3 ✓
- 单一入口(仅 footer)→ Task 3(不加菜单/HelpView)✓
- i18n zh+en → Task 2/3 默认值 + Task 4 en ✓
- parseCSV 边界测试 → Task 1 ✓
- 文档同步四份 → Task 4 ✓
- 合规(不给商业外链、只点名 ECDICT)→ Task 2 内容 ✓

**Placeholder scan:** 无 TBD/TODO;所有步骤含实际代码/命令/预期。Task 4 Step 4 对 HELP.md 用了条件判断(grep 后决定),已给出明确的判定与两种走向,非模糊占位。

**Type consistency:** `DictionaryImportGuideView()` 无参 init(Task 2 定义 → Task 3 使用)一致;`Notification.Name.showDictionaryImportGuide`(Task 3 Step 1 定义 → Step 4 使用)一致;`CSVRow(word:definition:phonetic:)` 与 Models 中定义一致;`parseCSV` 返回 `[CSVRow]` 一致。

**Test count:** Kit 61 → 70(+9,Task 1)。
