# 懒人词包(Word Packs)实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为新用户提供按难度/场景预置的离线词包,一键导入即可学习;导入词与手动收录词以「文件夹式分组」隔离,学习时可按分组单选切换。

**Architecture:** 新增 `WordGroup` SwiftData 模型,`WordEntry` 加可选 `group` 关系(nil 兜底为「手动收录」);去重口径从「全库按 lemma」改为「按(分组+lemma)」。词包由 Python 脚本从完整 ECDICT(`data/ecdict.db`,MIT)离线生成为 JSON,随 App bundle 分发;`WordPackImporter`(WordClipKit,纯逻辑可测)解析并幂等导入。`StudySession` 增加分组过滤。UI 加首启引导 + 长驻词包浏览 + 分组选择器。

**Tech Stack:** Swift 6 · SwiftData · SwiftUI · WordClipKit(SPM 包)· Swift Testing(`import Testing` / `@Test` / `#expect`)· GRDB(仅构建脚本侧不用,App 侧词典已有)· Python 3(构建脚本,读 sqlite3)

## Global Constraints

- 语言/平台:macOS 15+ / iOS 18+;WordClipKit `swift-tools-version: 6.0`。
- SwiftData + CloudKit 兼容约束(现有):**不使用 `@Attribute(.unique)`**;所有模型属性有默认值或可选;关系可选。去重在应用层完成。
- 词包全部**免费**(不加 Pro 闸门)。
- 词包**离线**随 App 分发,零联网。
- 分级包从 `data/ecdict.db`(完整 ECDICT,含 `tag` 列)生成,**不是** `WordClip/Resources/dictionary-en.sqlite`(裁剪版已丢 tag)。
- ECDICT tag 匹配必须用空格 padding 防子串误匹配:`(' '||tag||' ') LIKE '% cet4 %'`。
- 场景包每包 300–500 词,500 为上限,不注水;分级包按 tag 全量。
- 导入词初始 `lastReviewedAt = nil`(全新词)。
- 测试框架用 Swift Testing(不是 XCTest);测试放 `WordClipKit/Tests/WordClipKitTests/`。
- 单一分组归属:一个 `WordEntry` 只属于一个 `WordGroup`。
- 提交信息结尾附:`Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`

---

## 文件结构

**新增:**
- `WordClipKit/Sources/WordClipKit/Models/Models.swift` — 追加 `WordGroup` 模型 + `WordEntry.group` 字段(改现有文件)
- `WordClipKit/Sources/WordClipKit/Pack/WordPack.swift` — 词包 JSON 的 Codable DTO(`WordPackDTO` / `WordPackWordDTO`)
- `WordClipKit/Sources/WordClipKit/Pack/WordPackImporter.swift` — 纯解析逻辑(解码 JSON、去重判定),不碰 SwiftData
- `WordClipKit/Tests/WordClipKitTests/WordPackTests.swift` — 上述纯逻辑单测
- `WordClip/Services/WordPackCatalog.swift` — 枚举 bundle 内 `wordpacks/*.json`,读元信息
- `WordClip/Services/WordPackStore.swift` — App 端落库:找/建 `WordGroup`、逐词 upsert、幂等
- `WordClip/Views/WordPackBrowserView.swift` — 词包列表(首启引导与长驻共用)
- `WordClip/Views/GroupPicker.swift` — 分组选择器组件
- `data/build_wordpacks.py` — 构建脚本
- `data/wordpacks/*.txt` — 场景包策划词表(纯词表)
- `WordClip/Resources/wordpacks/pack-*.json` — 构建产物(入 bundle)

**改动:**
- `WordClip/App/WordClipApp.swift` — `Schema` 加 `WordGroup.self`;首启引导挂载
- `WordClip/Services/WordCollector.swift` — 去重加分组;手动词归入手动组
- `WordClip/App/WordClipApp.swift`(OCR 流程)— 去重口径随 collector 改动自动生效(无需单独改)
- `WordClip/Services/StudySession.swift` — 分组过滤 + `selectedGroupID`
- `WordClip/Views/StudyView.swift` / `StatsView.swift` — 挂 GroupPicker

**任务顺序理由:** 先落数据模型(Task 1),再纯逻辑 DTO/Importer(Task 2–3,可离线单测),再构建脚本产出真实数据(Task 4),然后 App 端落库(Task 5)、去重改造(Task 6)、学习分组过滤(Task 7),最后 UI(Task 8–9)。

---

## Task 1: WordGroup 模型 + WordEntry.group 字段

**Files:**
- Modify: `WordClipKit/Sources/WordClipKit/Models/Models.swift`
- Test: `WordClipKit/Tests/WordClipKitTests/WordPackTests.swift`(本任务新建文件,先放模型冒烟测)

**Interfaces:**
- Produces:
  - `WordGroup`(`@Model final class`),属性:`id: UUID`、`name: String`、`kind: String`、`packSlug: String?`、`iconSymbol: String?`、`sortOrder: Int`、`createdAt: Date`;init 签名 `init(name: String, kind: String, packSlug: String? = nil, iconSymbol: String? = nil, sortOrder: Int = 0)`
  - 常量:`WordGroup.kindManual = "manual"`、`WordGroup.kindPack = "pack"`、`WordGroup.manualGroupName = "手动收录"`
  - `WordEntry.group: WordGroup?`(可选关系,默认 nil)

- [ ] **Step 1: 在 Models.swift 追加 WordGroup 模型**

在 `Models.swift` 的 `// MARK: - CollectSource` 之前插入:

```swift
// MARK: - WordGroup

/// 词条分组:手动收录集 或 某个懒人词包。
/// 单一归属:一个 WordEntry 只属于一个 WordGroup。
/// CloudKit 建模约束:无 .unique,属性有默认值或可选。
@Model
public final class WordGroup {

    public var id: UUID
    public var name: String            // "手动收录" / "旅游娱乐" / "考研核心"
    public var kind: String            // kindManual | kindPack
    public var packSlug: String?       // 包稳定标识(如 "travel"、"cet4");manual 组为 nil
    public var iconSymbol: String?     // SF Symbol 名
    public var sortOrder: Int
    public var createdAt: Date

    public init(
        name: String,
        kind: String,
        packSlug: String? = nil,
        iconSymbol: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.kind = kind
        self.packSlug = packSlug
        self.iconSymbol = iconSymbol
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}

extension WordGroup {
    public static let kindManual = "manual"
    public static let kindPack = "pack"
    public static let manualGroupName = "手动收录"
}
```

- [ ] **Step 2: 给 WordEntry 加 group 字段**

在 `WordEntry` 的 `sources` 关系声明**之后**、`init` 之前追加属性:

```swift
    // MARK: 分组归属(nil 视为「手动收录」组,存量老词无需迁移)
    // 单向可选关系(WordGroup 侧不设反向数组,保持模型简单 + CloudKit 友好)。
    @Relationship(deleteRule: .nullify)
    public var group: WordGroup?
```

`WordEntry.init` 内不需要初始化 `group`(可选默认 nil)。

- [ ] **Step 3: 写模型冒烟测(新建 WordPackTests.swift)**

创建 `WordClipKit/Tests/WordClipKitTests/WordPackTests.swift`:

```swift
import Testing
import Foundation
@testable import WordClipKit

@Suite("WordGroup model")
struct WordGroupModelTests {

    @Test("WordGroup 初始化与常量")
    func initAndConstants() {
        let g = WordGroup(name: "旅游娱乐", kind: WordGroup.kindPack, packSlug: "travel", iconSymbol: "airplane", sortOrder: 3)
        #expect(g.name == "旅游娱乐")
        #expect(g.kind == "pack")
        #expect(g.packSlug == "travel")
        #expect(g.iconSymbol == "airplane")
        #expect(g.sortOrder == 3)
        #expect(WordGroup.kindManual == "manual")
        #expect(WordGroup.manualGroupName == "手动收录")
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd WordClipKit && swift test --filter WordGroupModelTests`
Expected: PASS(1 test)。若报编译错误,先修 Models.swift。

- [ ] **Step 5: 提交**

```bash
cd /Users/seven/Works/github/wordclip
git add WordClipKit/Sources/WordClipKit/Models/Models.swift WordClipKit/Tests/WordClipKitTests/WordPackTests.swift
git commit -m "feat(kit): WordGroup 模型 + WordEntry.group 分组归属

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 词包 JSON DTO(Codable)

**Files:**
- Create: `WordClipKit/Sources/WordClipKit/Pack/WordPack.swift`
- Test: `WordClipKit/Tests/WordClipKitTests/WordPackTests.swift`(追加 Suite)

**Interfaces:**
- Consumes: 无
- Produces:
  - `public struct WordPackWordDTO: Codable, Equatable, Sendable`,字段:`headword: String`、`lemma: String`、`definition: String?`、`definitionEn: String?`、`phonetic: String?`
  - `public struct WordPackDTO: Codable, Equatable, Sendable`,字段:`slug: String`、`name: String`、`icon: String?`、`kind: String`、`version: Int`、`language: String`、`words: [WordPackWordDTO]`
  - `WordPackDTO.decode(from data: Data) throws -> WordPackDTO`(静态方法,内部 `JSONDecoder`)

- [ ] **Step 1: 写失败测试(追加到 WordPackTests.swift)**

```swift
@Suite("WordPackDTO decoding")
struct WordPackDTODecodingTests {

    @Test("从 JSON 解码词包")
    func decodePack() throws {
        let json = """
        {
          "slug": "travel", "name": "旅游娱乐", "icon": "airplane",
          "kind": "pack", "version": 1, "language": "en",
          "words": [
            {"headword": "itinerary", "lemma": "itinerary", "definition": "n. 行程", "definitionEn": "a route", "phonetic": "aɪ"},
            {"headword": "Visa", "lemma": "visa", "definition": "n. 签证"}
          ]
        }
        """.data(using: .utf8)!

        let pack = try WordPackDTO.decode(from: json)
        #expect(pack.slug == "travel")
        #expect(pack.name == "旅游娱乐")
        #expect(pack.icon == "airplane")
        #expect(pack.version == 1)
        #expect(pack.words.count == 2)
        #expect(pack.words[0].lemma == "itinerary")
        #expect(pack.words[1].definitionEn == nil)   // 可选字段缺省
        #expect(pack.words[1].phonetic == nil)
    }
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd WordClipKit && swift test --filter WordPackDTODecodingTests`
Expected: FAIL(编译错误 "cannot find 'WordPackDTO'")。

- [ ] **Step 3: 创建 WordPack.swift**

```swift
import Foundation

/// 词包中的单个词。释义在构建时由 ECDICT 补全,导入时无需再查库。
public struct WordPackWordDTO: Codable, Equatable, Sendable {
    public let headword: String
    public let lemma: String
    public let definition: String?
    public let definitionEn: String?
    public let phonetic: String?

    public init(headword: String, lemma: String, definition: String? = nil,
                definitionEn: String? = nil, phonetic: String? = nil) {
        self.headword = headword
        self.lemma = lemma
        self.definition = definition
        self.definitionEn = definitionEn
        self.phonetic = phonetic
    }
}

/// 一个懒人词包(分级包或场景包)的离线 JSON 结构。
public struct WordPackDTO: Codable, Equatable, Sendable {
    public let slug: String
    public let name: String
    public let icon: String?
    public let kind: String
    public let version: Int
    public let language: String
    public let words: [WordPackWordDTO]

    public init(slug: String, name: String, icon: String? = nil, kind: String = "pack",
                version: Int = 1, language: String = "en", words: [WordPackWordDTO]) {
        self.slug = slug
        self.name = name
        self.icon = icon
        self.kind = kind
        self.version = version
        self.language = language
        self.words = words
    }

    public static func decode(from data: Data) throws -> WordPackDTO {
        try JSONDecoder().decode(WordPackDTO.self, from: data)
    }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `cd WordClipKit && swift test --filter WordPackDTODecodingTests`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
cd /Users/seven/Works/github/wordclip
git add WordClipKit/Sources/WordClipKit/Pack/WordPack.swift WordClipKit/Tests/WordClipKitTests/WordPackTests.swift
git commit -m "feat(kit): 词包 JSON DTO(WordPackDTO / WordPackWordDTO)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: WordPackImporter 纯去重逻辑

App 端落库需要「本组已有哪些 lemma → 只导入差集」。把这个纯计算抽出来单测,SwiftData 交互留到 Task 5。

**Files:**
- Create: `WordClipKit/Sources/WordClipKit/Pack/WordPackImporter.swift`
- Test: `WordClipKit/Tests/WordClipKitTests/WordPackTests.swift`(追加 Suite)

**Interfaces:**
- Consumes: `WordPackDTO`、`WordPackWordDTO`(Task 2)
- Produces:
  - `public enum WordPackImporter`
  - `static func newWords(in pack: WordPackDTO, existingLemmas: Set<String>) -> [WordPackWordDTO]` — 返回 pack 中 lemma 不在 `existingLemmas` 的词,保持原序,且对 pack 内部重复 lemma 也去重(首个保留)

- [ ] **Step 1: 写失败测试**

```swift
@Suite("WordPackImporter dedup")
struct WordPackImporterTests {

    private func pack(_ lemmas: [String]) -> WordPackDTO {
        WordPackDTO(slug: "t", name: "T", words: lemmas.map {
            WordPackWordDTO(headword: $0, lemma: $0)
        })
    }

    @Test("过滤掉本组已存在的 lemma")
    func filtersExisting() {
        let p = pack(["apple", "banana", "cherry"])
        let result = WordPackImporter.newWords(in: p, existingLemmas: ["banana"])
        #expect(result.map(\.lemma) == ["apple", "cherry"])
    }

    @Test("pack 内部重复 lemma 只保留首个")
    func dedupWithinPack() {
        let p = pack(["apple", "apple", "banana"])
        let result = WordPackImporter.newWords(in: p, existingLemmas: [])
        #expect(result.map(\.lemma) == ["apple", "banana"])
    }

    @Test("全部已存在返回空")
    func allExisting() {
        let p = pack(["apple", "banana"])
        let result = WordPackImporter.newWords(in: p, existingLemmas: ["apple", "banana"])
        #expect(result.isEmpty)
    }

    @Test("保持原始顺序")
    func preservesOrder() {
        let p = pack(["zebra", "alpha", "mango"])
        let result = WordPackImporter.newWords(in: p, existingLemmas: [])
        #expect(result.map(\.lemma) == ["zebra", "alpha", "mango"])
    }
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd WordClipKit && swift test --filter WordPackImporterTests`
Expected: FAIL("cannot find 'WordPackImporter'")。

- [ ] **Step 3: 创建 WordPackImporter.swift**

```swift
import Foundation

/// 词包导入的纯逻辑部分(去重计算),不依赖 SwiftData,便于单测。
/// 落库(找/建 WordGroup、插入 WordEntry)在 App 端 WordPackStore 完成。
public enum WordPackImporter {

    /// 返回 pack 中「本组尚未存在」的词,保持原序;pack 内部重复 lemma 只留首个。
    public static func newWords(in pack: WordPackDTO, existingLemmas: Set<String>) -> [WordPackWordDTO] {
        var seen = existingLemmas
        var result: [WordPackWordDTO] = []
        for word in pack.words {
            let key = word.lemma.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(word)
        }
        return result
    }
}
```

- [ ] **Step 4: 运行确认通过**

Run: `cd WordClipKit && swift test --filter WordPackImporterTests`
Expected: PASS(4 tests)。

- [ ] **Step 5: 全量跑 Kit 测试确认无回归**

Run: `cd WordClipKit && swift test`
Expected: 全部 PASS(含原有 Suite)。

- [ ] **Step 6: 提交**

```bash
cd /Users/seven/Works/github/wordclip
git add WordClipKit/Sources/WordClipKit/Pack/WordPackImporter.swift WordClipKit/Tests/WordClipKitTests/WordPackTests.swift
git commit -m "feat(kit): WordPackImporter 组内去重纯逻辑

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 构建脚本 + 首发词包数据

生成 `pack-*.json` 到 `WordClip/Resources/wordpacks/`。分级包用 ECDICT tag;场景包用策划词表 + ECDICT 补全释义。

**Files:**
- Create: `data/build_wordpacks.py`
- Create: `data/wordpacks/daily.txt`、`data/wordpacks/travel.txt`、`data/wordpacks/programming.txt`、`data/wordpacks/business.txt`(场景词表)
- Create: `WordClip/Resources/wordpacks/pack-*.json`(产物,共 12 个)

**Interfaces:**
- Consumes: `data/ecdict.db`(完整 ECDICT,含 `tag`)
- Produces: 12 个 `pack-<slug>.json`,结构匹配 Task 2 的 `WordPackDTO`

- [ ] **Step 1: 写构建脚本**

创建 `data/build_wordpacks.py`:

```python
#!/usr/bin/env python3
"""从完整 ECDICT(data/ecdict.db)构建懒人词包 JSON。

分级包:按 tag 全量筛,词频升序。
场景包:读 data/wordpacks/<slug>.txt(一行一词),用 ECDICT 补全释义,词频升序。
产物写到 WordClip/Resources/wordpacks/pack-<slug>.json。
"""
import json
import os
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DB = os.path.join(HERE, "ecdict.db")
OUT_DIR = os.path.join(HERE, "..", "WordClip", "Resources", "wordpacks")
WORDLIST_DIR = os.path.join(HERE, "wordpacks")

# 分级包:slug -> (显示名, ECDICT tag, SF Symbol)
LEVEL_PACKS = [
    ("beginner", "初学者(中考)", "zk", "leaf"),
    ("gaokao",   "高考",         "gk", "graduationcap"),
    ("cet4",     "CET-4",        "cet4", "book"),
    ("cet6",     "CET-6",        "cet6", "books.vertical"),
    ("kaoyan",   "考研",         "ky", "pencil.and.ruler"),
    ("toefl",    "托福 TOEFL",   "toefl", "airplane.circle"),
    ("ielts",    "雅思 IELTS",   "ielts", "globe"),
    ("gre",      "GRE",          "gre", "brain"),
]

# 场景包:slug -> (显示名, SF Symbol);词表来自 wordpacks/<slug>.txt
SCENE_PACKS = [
    ("daily",       "日常生活",       "house"),
    ("travel",      "旅游娱乐",       "airplane"),
    ("programming", "程序员/技术文档", "chevron.left.forwardslash.chevron.right"),
    ("business",    "商务职场",       "briefcase"),
]

SCENE_MAX = 500  # 场景包上限


def row_to_word(row):
    word, phonetic, translation, definition_en = row
    return {
        "headword": word,
        "lemma": word.lower(),
        "definition": translation or None,
        "definitionEn": definition_en or None,
        "phonetic": phonetic or None,
    }


def build_level(conn, slug, name, tag, icon):
    cur = conn.execute(
        """SELECT word, phonetic, translation, definition
           FROM stardict
           WHERE (' '||tag||' ') LIKE ?
           ORDER BY CASE WHEN frq>0 THEN frq ELSE 999999 END ASC, word ASC""",
        (f"% {tag} %",),
    )
    words = [row_to_word(r) for r in cur.fetchall()]
    return {"slug": slug, "name": name, "icon": icon, "kind": "pack",
            "version": 1, "language": "en", "words": words}


def build_scene(conn, slug, name, icon):
    path = os.path.join(WORDLIST_DIR, f"{slug}.txt")
    with open(path, encoding="utf-8") as f:
        lemmas = [ln.strip().lower() for ln in f if ln.strip() and not ln.startswith("#")]
    # 去重保序
    seen, ordered = set(), []
    for l in lemmas:
        if l not in seen:
            seen.add(l); ordered.append(l)
    words = []
    for lemma in ordered:
        cur = conn.execute(
            "SELECT word, phonetic, translation, definition FROM stardict WHERE word=? COLLATE NOCASE LIMIT 1",
            (lemma,),
        )
        row = cur.fetchone()
        if row:
            words.append(row_to_word(row))
        else:
            words.append({"headword": lemma, "lemma": lemma,
                          "definition": None, "definitionEn": None, "phonetic": None})
    words = words[:SCENE_MAX]
    return {"slug": slug, "name": name, "icon": icon, "kind": "pack",
            "version": 1, "language": "en", "words": words}


def main():
    if not os.path.exists(DB):
        sys.exit(f"找不到 {DB};请先在 data/ 下准备完整 ECDICT。")
    os.makedirs(OUT_DIR, exist_ok=True)
    conn = sqlite3.connect(DB)

    for slug, name, tag, icon in LEVEL_PACKS:
        pack = build_level(conn, slug, name, tag, icon)
        out = os.path.join(OUT_DIR, f"pack-{slug}.json")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(pack, f, ensure_ascii=False)
        print(f"{slug}: {len(pack['words'])} 词 -> {out}")

    for slug, name, icon in SCENE_PACKS:
        pack = build_scene(conn, slug, name, icon)
        out = os.path.join(OUT_DIR, f"pack-{slug}.json")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(pack, f, ensure_ascii=False)
        print(f"{slug}: {len(pack['words'])} 词 -> {out}")

    conn.close()


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: 起草场景包词表**

创建 4 个 `data/wordpacks/<slug>.txt`,一行一词(小写英文 lemma,`#` 开头为注释)。每个文件 300–500 词,按主题精选高频常用词、不注水。

`daily.txt` 示例开头(继续补至 ~400 词,覆盖:家居、食物、身体、衣物、时间、天气、情感、动作等):
```
# 日常生活 —— 家居/食物/身体/时间/天气/情感/日常动作
breakfast
lunch
dinner
kitchen
bedroom
umbrella
weather
morning
evening
weekend
```

`travel.txt` 开头(补至 300–400 词,覆盖:交通、住宿、机场、观光、餐饮、购物、问路):
```
# 旅游娱乐 —— 交通/住宿/机场/观光/餐饮/购物/问路
itinerary
passport
luggage
boarding
reservation
souvenir
sightseeing
customs
departure
arrival
```

`programming.txt` 开头(补至 ~500 词,覆盖:语言/数据结构/网络/数据库/工具/云):
```
# 程序员/技术文档 —— 语言/数据结构/网络/数据库/工具/云
algorithm
variable
function
compiler
database
deployment
repository
authentication
concurrency
latency
```

`business.txt` 开头(补至 ~450 词,覆盖:会议/邮件/财务/市场/合同/管理):
```
# 商务职场 —— 会议/邮件/财务/市场/合同/管理
agenda
invoice
revenue
stakeholder
negotiation
deadline
proposal
quarterly
logistics
compliance
```

> 实现者注:词表内容由实现方按主题补全至目标词量(daily~400 / travel~350 / programming~500 / business~450),全部小写、每行一词、无重复。补全后交用户审校。

- [ ] **Step 3: 运行构建脚本**

Run: `cd data && python3 build_wordpacks.py`
Expected 输出类似:
```
beginner: 1603 词 -> .../pack-beginner.json
gaokao: 3677 词 -> ...
...
daily: 400 词 -> ...
travel: 350 词 -> ...
programming: 500 词 -> ...
business: 450 词 -> ...
```

- [ ] **Step 4: 校验产物结构**

Run:
```bash
cd /Users/seven/Works/github/wordclip
python3 -c "import json,glob; [print(p, json.load(open(p))['slug'], len(json.load(open(p))['words'])) for p in sorted(glob.glob('WordClip/Resources/wordpacks/pack-*.json'))]"
```
Expected: 12 行,每行 slug 与词数;词数 > 0。

- [ ] **Step 5: 确认 wordpacks 目录已加入 Xcode target 的 Resources**

打开 `WordClip.xcodeproj`,确认 `WordClip/Resources/wordpacks/` 作为 folder reference 或各 json 已加入 `WordClip-macOS` 与 `WordClip-iOS` 两个 target 的 Copy Bundle Resources。
Run 验证(构建后):见 Task 5 的 catalog 测试。

- [ ] **Step 6: 提交**

```bash
cd /Users/seven/Works/github/wordclip
git add data/build_wordpacks.py data/wordpacks/ WordClip/Resources/wordpacks/
git commit -m "feat(data): 词包构建脚本 + 首发 8 分级包 / 4 场景包

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

> 注:`.gitignore` 排除的是 ecdict 原始大文件;`pack-*.json` 是小体积产物,应入库随 App 分发。若被 gitignore 拦截用 `git add -f`。

---

## Task 5: WordPackCatalog + WordPackStore(App 端落库)

**Files:**
- Create: `WordClip/Services/WordPackCatalog.swift`
- Create: `WordClip/Services/WordPackStore.swift`

**Interfaces:**
- Consumes: `WordPackDTO.decode(from:)`(Task 2)、`WordPackImporter.newWords(in:existingLemmas:)`(Task 3)、`WordGroup`/`WordEntry`(Task 1)
- Produces:
  - `WordPackCatalog.all() -> [WordPackDTO]`(读 bundle 内所有 `wordpacks/pack-*.json`)
  - `@MainActor final class WordPackStore`,`init(modelContext: ModelContext)`
  - `WordPackStore.isImported(slug: String) -> Bool`
  - `WordPackStore.importedCount(slug: String) -> Int`
  - `WordPackStore.import(_ pack: WordPackDTO) -> Int`(返回新增词数;幂等)
  - `WordPackStore.manualGroup() -> WordGroup`(找/建手动组)

- [ ] **Step 1: 写 WordPackCatalog**

```swift
import Foundation
import WordClipKit

/// 读取 App bundle 内的词包清单(Resources/wordpacks/pack-*.json)。
enum WordPackCatalog {

    /// 解析全部词包,按文件名排序。解码失败的跳过。
    static func all() -> [WordPackDTO] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "wordpacks") else {
            return []
        }
        var packs: [WordPackDTO] = []
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let data = try? Data(contentsOf: url),
                  let pack = try? WordPackDTO.decode(from: data) else { continue }
            packs.append(pack)
        }
        return packs
    }
}
```

- [ ] **Step 2: 写 WordPackStore**

```swift
import Foundation
import SwiftData
import WordClipKit

/// 词包落库:找/建 WordGroup,把 DTO 词写入 SwiftData(组内去重、幂等)。
@MainActor
final class WordPackStore {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// 找或建「手动收录」组。
    func manualGroup() -> WordGroup {
        if let g = fetchGroup(kind: WordGroup.kindManual, slug: nil) { return g }
        let g = WordGroup(name: WordGroup.manualGroupName, kind: WordGroup.kindManual, sortOrder: 0)
        modelContext.insert(g)
        try? modelContext.save()
        return g
    }

    func isImported(slug: String) -> Bool { importedCount(slug: slug) > 0 }

    func importedCount(slug: String) -> Int {
        guard let g = fetchGroup(kind: WordGroup.kindPack, slug: slug) else { return 0 }
        let gid = g.id
        let d = FetchDescriptor<WordEntry>(predicate: #Predicate { $0.group?.id == gid })
        return (try? modelContext.fetchCount(d)) ?? 0
    }

    /// 导入词包,返回新增词数。幂等:重复导入只补差集。
    @discardableResult
    func `import`(_ pack: WordPackDTO) -> Int {
        // 找/建目标组
        let group: WordGroup
        if let g = fetchGroup(kind: WordGroup.kindPack, slug: pack.slug) {
            group = g
        } else {
            group = WordGroup(name: pack.name, kind: WordGroup.kindPack,
                              packSlug: pack.slug, iconSymbol: pack.icon, sortOrder: 1)
            modelContext.insert(group)
        }

        // 本组已有 lemma 集合
        let gid = group.id
        let existing = (try? modelContext.fetch(
            FetchDescriptor<WordEntry>(predicate: #Predicate { $0.group?.id == gid })
        )) ?? []
        let existingLemmas = Set(existing.map { $0.lemma.lowercased() })

        let newWords = WordPackImporter.newWords(in: pack, existingLemmas: existingLemmas)
        for w in newWords {
            let entry = WordEntry(headword: w.headword, lemma: w.lemma.lowercased(), language: pack.language)
            entry.definition = w.definition
            entry.definitionEn = w.definitionEn
            entry.phonetic = w.phonetic
            entry.group = group      // 全新词:lastReviewedAt 默认 nil
            modelContext.insert(entry)
        }
        try? modelContext.save()
        return newWords.count
    }

    private func fetchGroup(kind: String, slug: String?) -> WordGroup? {
        let d: FetchDescriptor<WordGroup>
        if let slug {
            d = FetchDescriptor<WordGroup>(predicate: #Predicate { $0.kind == kind && $0.packSlug == slug })
        } else {
            d = FetchDescriptor<WordGroup>(predicate: #Predicate { $0.kind == kind })
        }
        return try? modelContext.fetch(d).first
    }
}
```

- [ ] **Step 3: 构建 macOS target 确认编译通过**

Run: `xcodebuild -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 手动冒烟验证 catalog 能读到 12 个包**

在 `WordPackStore` 或 App 启动处临时加一行 `print("packs:", WordPackCatalog.all().count)`,运行 App 看控制台输出 `packs: 12`;确认后移除该临时打印。(或在 Task 8 的 UI 里自然验证。)

- [ ] **Step 5: 提交**

```bash
cd /Users/seven/Works/github/wordclip
git add WordClip/Services/WordPackCatalog.swift WordClip/Services/WordPackStore.swift
git commit -m "feat: WordPackCatalog 读 bundle + WordPackStore 幂等落库

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 手动收录去重加入分组归属

现有 `WordCollector.upsert` 全库按 lemma 去重。改为:手动词归入「手动收录」组,组内去重。

**Files:**
- Modify: `WordClip/Services/WordCollector.swift`

**Interfaces:**
- Consumes: `WordPackStore.manualGroup()`(Task 5)、`WordGroup`(Task 1)
- Produces: 手动/OCR 收录的 `WordEntry.group` 指向手动组;`fetchEntry` 在手动组内查

- [ ] **Step 1: 给 WordCollector 注入手动组解析**

`WordCollector` 增加一个惰性获取手动组的方法(复用 WordPackStore 的逻辑,避免重复):在 `WordCollector` 内加属性与方法:

```swift
    /// 手动收录组(惰性找/建)。手动/OCR 收录的词都归入此组。
    private lazy var manualGroupStore = WordPackStore(modelContext: modelContext)

    private func manualGroup() -> WordGroup {
        manualGroupStore.manualGroup()
    }
```

- [ ] **Step 2: 改 upsert:组内去重 + 赋 group**

将 `upsert` 的 `fetchEntry(lemma:)` 调用与新建分支改为组感知。替换 `fetchEntry` 方法:

```swift
    private func fetchEntry(lemma: String) -> WordEntry? {
        let group = manualGroup()
        let gid = group.id
        let descriptor = FetchDescriptor<WordEntry>(
            predicate: #Predicate { $0.lemma == lemma && $0.group?.id == gid }
        )
        return try? modelContext.fetch(descriptor).first
    }
```

并在 `upsert` 新建 `WordEntry` 的分支里,`modelContext.insert(entry)` 之前加:

```swift
            entry.group = manualGroup()
```

(定位:`upsert` 内 `else { entry = WordEntry(...) ... modelContext.insert(entry) }` 分支。)

- [ ] **Step 3: 构建 macOS + iOS 确认编译**

Run:
```bash
xcodebuild -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 手动验证去重与隔离**

启动 App:
1. 手动收录一个词(如 "hello")→ 应进「手动收录」组。
2. 导入含 "hello" 的词包(若有)→ 该词在包组独立存在一份,互不影响。
3. 重复手动收录 "hello" → 不新建,只加 CollectSource。

- [ ] **Step 5: 提交**

```bash
cd /Users/seven/Works/github/wordclip
git add WordClip/Services/WordCollector.swift
git commit -m "feat: 手动/OCR 收录归入「手动收录」组,组内去重

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: StudySession 分组过滤

**Files:**
- Modify: `WordClip/Services/StudySession.swift`

**Interfaces:**
- Consumes: `WordGroup`(Task 1)
- Produces:
  - `StudySession.selectedGroupID: UUID?`(`@Published`,`nil` = 全部)
  - `StudySession.setGroup(_ id: UUID?)` — 设置并持久化到 UserDefaults 键 `study.selectedGroup`
  - `fetchAll()` 依 `selectedGroupID` 过滤

- [ ] **Step 1: 加 selectedGroupID + 持久化**

在 `StudySession` 的 `@Published` 区加:

```swift
    /// 当前学习的分组;nil = 全部分组混学。持久化到 UserDefaults。
    @Published var selectedGroupID: UUID?

    private static let selectedGroupKey = "study.selectedGroup"
```

在 `init` 末尾恢复:

```swift
        if let s = UserDefaults.standard.string(forKey: Self.selectedGroupKey),
           let id = UUID(uuidString: s) {
            selectedGroupID = id
        }
```

加设置方法:

```swift
    /// 切换分组并持久化;调用后应 refreshStats()。
    func setGroup(_ id: UUID?) {
        selectedGroupID = id
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: Self.selectedGroupKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.selectedGroupKey)
        }
        refreshStats()
    }
```

- [ ] **Step 2: fetchAll 加分组过滤**

替换 `fetchAll()`:

```swift
    private func fetchAll() -> [WordEntry] {
        guard let ctx = modelContext else { return [] }
        var descriptor = FetchDescriptor<WordEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        if let gid = selectedGroupID {
            descriptor.predicate = #Predicate { $0.group?.id == gid }
        }
        return (try? ctx.fetch(descriptor)) ?? []
    }
```

> 注:这里用 `$0.group?.id == gid`(UUID 比较),与 selectedGroupID 类型一致。

- [ ] **Step 3: 构建确认编译**

Run: `xcodebuild -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 手动验证**

启动 App:选中某词包组 → 学习队列只出该组的词;切到「全部」→ 所有组混学;`refreshStats` 数字随分组变化。

- [ ] **Step 5: 提交**

```bash
cd /Users/seven/Works/github/wordclip
git add WordClip/Services/StudySession.swift
git commit -m "feat: 学习会话按分组过滤(selectedGroupID + 持久化)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 词包浏览/导入 UI(首启引导 + 长驻)

**Files:**
- Create: `WordClip/Views/WordPackBrowserView.swift`
- Modify: `WordClip/App/WordClipApp.swift`(Schema 加 WordGroup;首启挂载入口)

**Interfaces:**
- Consumes: `WordPackCatalog.all()`、`WordPackStore`(Task 5)
- Produces: `WordPackBrowserView`(SwiftUI View),可多选未导入包 → 一键导入

- [ ] **Step 1: Schema 加 WordGroup**

`WordClipApp.swift` 的 `Schema([...])` 加一行:

```swift
        let schema = Schema([
            WordEntry.self,
            CollectSource.self,
            ReviewLog.self,
            WordGroup.self,
        ])
```

- [ ] **Step 2: 写 WordPackBrowserView**

```swift
import SwiftUI
import SwiftData
import WordClipKit

/// 词包浏览与导入:网格列出所有包,已导入显示「已添加」,未导入可勾选批量导入。
struct WordPackBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    /// 首启引导模式:显示「跳过」;长驻模式:显示「完成」。
    var isOnboarding: Bool = false
    var onDone: () -> Void = {}

    @State private var packs: [WordPackDTO] = []
    @State private var selected: Set<String> = []
    @State private var importedCounts: [String: Int] = [:]
    @State private var isImporting = false

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isOnboarding
                 ? String(localized: "packs.welcome.title", defaultValue: "选择词包,快速开始")
                 : String(localized: "packs.browse.title", defaultValue: "词包"))
                .font(.title2).bold()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(packs, id: \.slug) { pack in
                        card(pack)
                    }
                }
            }

            HStack {
                Button(isOnboarding
                       ? String(localized: "packs.skip", defaultValue: "跳过")
                       : String(localized: "packs.close", defaultValue: "关闭")) { onDone() }
                Spacer()
                Button {
                    importSelected()
                } label: {
                    Text(String(localized: "packs.import", defaultValue: "导入 (\(selected.count))"))
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty || isImporting)
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 480)
        .task { load() }
    }

    private func card(_ pack: WordPackDTO) -> some View {
        let imported = (importedCounts[pack.slug] ?? 0) > 0
        let isOn = selected.contains(pack.slug)
        return Button {
            guard !imported else { return }
            if isOn { selected.remove(pack.slug) } else { selected.insert(pack.slug) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: pack.icon ?? "square.stack")
                    .font(.title2).frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.name).font(.headline)
                    Text("\(pack.words.count) 词").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if imported {
                    Label(String(localized: "packs.added", defaultValue: "已添加"), systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly).foregroundStyle(.green)
                } else if isOn {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(imported ? 0.06 : 0.12)))
            .opacity(imported ? 0.6 : 1)
        }
        .buttonStyle(.plain)
    }

    private func load() {
        packs = WordPackCatalog.all()
        let store = WordPackStore(modelContext: modelContext)
        var counts: [String: Int] = [:]
        for p in packs { counts[p.slug] = store.importedCount(slug: p.slug) }
        importedCounts = counts
    }

    private func importSelected() {
        isImporting = true
        let store = WordPackStore(modelContext: modelContext)
        for pack in packs where selected.contains(pack.slug) {
            store.import(pack)
        }
        selected.removeAll()
        load()
        isImporting = false
        if isOnboarding { onDone() }
    }
}
```

- [ ] **Step 3: 首启引导挂载**

在主界面(`ContentView` 或 `WordClipApp` 的主 Window body)加:库为空时以 `.sheet` 呈现 `WordPackBrowserView(isOnboarding: true)`。用 UserDefaults 键 `packs.onboarded` 记录已展示过,避免每次空库都弹。

在主 Window 的 View 上加(示例,具体挂在 `ContentView`):

```swift
    @AppStorage("packs.onboarded") private var packsOnboarded = false
    @State private var showOnboarding = false
    @Query private var allWords: [WordEntry]

    // 在 .onAppear / .task:
    //   if allWords.isEmpty && !packsOnboarded { showOnboarding = true }
    // .sheet(isPresented: $showOnboarding) {
    //     WordPackBrowserView(isOnboarding: true) {
    //         packsOnboarded = true; showOnboarding = false
    //     }
    // }
```

> 实现者注:`ContentView` 若已有 `@Query`,复用即可;挂载点选主内容视图,确保 modelContext 已注入。

- [ ] **Step 4: 构建 macOS + iOS**

Run:
```bash
xcodebuild -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 手动验证首启流程**

删除 App 数据(或新模拟器)→ 首次启动 → 弹词包引导 → 勾选 2 个包 → 导入 → 进入学习能看到这些词。重启 App 不再弹引导。

- [ ] **Step 6: 提交**

```bash
cd /Users/seven/Works/github/wordclip
git add WordClip/Views/WordPackBrowserView.swift WordClip/App/WordClipApp.swift
git commit -m "feat: 词包浏览/导入 UI + 首启引导 + Schema 注册 WordGroup

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: 分组选择器接入学习/统计页 + 长驻入口

**Files:**
- Create: `WordClip/Views/GroupPicker.swift`
- Modify: `WordClip/Views/StudyView.swift`
- Modify: `WordClip/Views/StatsView.swift`(如统计需按组;否则仅接 StudyView)
- Modify: 主菜单/设置(`MenuBarMenuView.swift` 或 `MainViews.swift`)加「词包」长驻入口

**Interfaces:**
- Consumes: `WordGroup`(Task 1)、`StudySession.setGroup(_:)`/`selectedGroupID`(Task 7)、`WordPackBrowserView`(Task 8)
- Produces: `GroupPicker`(SwiftUI View,`@Binding selection: UUID?`)

- [ ] **Step 1: 写 GroupPicker**

```swift
import SwiftUI
import SwiftData
import WordClipKit

/// 分组选择器:全部 + 各分组(手动收录、各词包)。
struct GroupPicker: View {
    @Binding var selection: UUID?          // nil = 全部
    @Query(sort: \WordGroup.sortOrder) private var groups: [WordGroup]

    var body: some View {
        Picker(String(localized: "study.group", defaultValue: "分组"), selection: $selection) {
            Text(String(localized: "study.group.all", defaultValue: "全部")).tag(UUID?.none)
            ForEach(groups) { g in
                Label(g.name, systemImage: g.iconSymbol ?? "square.stack").tag(UUID?.some(g.id))
            }
        }
        .pickerStyle(.menu)
    }
}
```

- [ ] **Step 2: 接入 StudyView**

在 `StudyView` 顶部(会话未开始/idle 时)加选择器,绑定到 session:

```swift
    // 在 StudyView body 顶部合适位置:
    GroupPicker(selection: Binding(
        get: { session.selectedGroupID },
        set: { session.setGroup($0) }
    ))
```

确保切换分组后 `session.refreshStats()` 被调用(`setGroup` 内已调)。

- [ ] **Step 3: 长驻词包入口**

在菜单栏菜单(`MenuBarMenuView.swift`)或主界面工具栏加一个按钮,打开 `WordPackBrowserView(isOnboarding: false)`(用 sheet 或独立窗口)。macOS 可用 `.sheet`;确保注入 `modelContainer` 的 context。

示例(菜单项):
```swift
    Button(String(localized: "menu.wordpacks", defaultValue: "词包…")) {
        // 触发打开 WordPackBrowserView 的状态
    }
```

> 实现者注:具体挂载方式跟随现有设置/菜单打开模式(参考 OCRWordPicker 用独立 panel 或现有 settings sheet)。

- [ ] **Step 4: 构建 macOS + iOS**

Run: `xcodebuild -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 手动验证**

1. StudyView 顶部出现分组选择器,切换后学习集随之变化。
2. 长驻入口能再次打开词包浏览,补导入未导入的包。
3. 已导入的包显示「已添加」。

- [ ] **Step 6: 提交**

```bash
cd /Users/seven/Works/github/wordclip
git add WordClip/Views/GroupPicker.swift WordClip/Views/StudyView.swift WordClip/Views/StatsView.swift WordClip/Views/MenuBarMenuView.swift
git commit -m "feat: 分组选择器接入学习页 + 词包长驻入口

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: 端到端验证 + 文档同步

**Files:**
- Modify: `HELP.md`(补词包说明)
- Modify: `docs/PROGRESS.md`(记录新功能)

- [ ] **Step 1: 全量 Kit 测试**

Run: `cd WordClipKit && swift test`
Expected: 全部 PASS。

- [ ] **Step 2: 两端构建**

Run:
```bash
cd /Users/seven/Works/github/wordclip
xcodebuild -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -3
xcodebuild -scheme WordClip-iOS -configuration Debug -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -3
```
Expected: 两个 `** BUILD SUCCEEDED **`

- [ ] **Step 3: 端到端手动走查(全新数据)**

1. 全新启动 → 首启引导弹出。
2. 勾选「初学者」+「旅游娱乐」→ 导入。
3. 进学习页,分组选择器切「旅游娱乐」→ 只学旅游词。
4. 手动收录一个新词 → 切「手动收录」组能看到它,且与包词隔离。
5. 重开长驻词包入口 → 补导入「CET4」→ 学习页出现该组。
6. 重复导入同一包 → 词数不翻倍(幂等)。

- [ ] **Step 4: 更新 HELP.md**

在 HELP.md 合适位置加「词包」小节:说明首次启动可选词包、设置里可随时添加、学习页可按分组切换、全部免费离线。

- [ ] **Step 5: 更新 docs/PROGRESS.md**

在功能清单加一行:懒人词包(分级+场景,离线,分组隔离,分组学习)。

- [ ] **Step 6: 提交**

```bash
cd /Users/seven/Works/github/wordclip
git add HELP.md docs/PROGRESS.md
git commit -m "docs: 词包功能说明(HELP + PROGRESS)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 自查:Spec 覆盖对照

| Spec 要求 | 对应任务 |
|-----------|---------|
| 分级包 + 场景包两类 | Task 4 |
| 文件夹式分组隔离(单一归属) | Task 1(模型)+ Task 6(手动)+ Task 5(包) |
| 学习按分组单选切换 | Task 7 + Task 9 |
| 离线随 App 分发 | Task 4(产物入 bundle)+ Task 5(读 bundle) |
| 全部免费(无 Pro 闸门) | 全程不加闸门 |
| 导入词当全新词 | Task 5(不设 lastReviewedAt) |
| 首启引导 + 长驻入口 | Task 8 + Task 9 |
| 分级包按 ECDICT tag 全量 | Task 4(LEVEL_PACKS,空格 padding) |
| 场景包 300–500 词,500 上限 | Task 4(SCENE_MAX=500 + 词表) |
| CloudKit 兼容(无 unique/可选) | Task 1(WordGroup 建模) |
| 存量老词免迁移(nil 兜底) | Task 1(group 可选)+ Task 6/7(nil 归手动) |

无遗漏。
