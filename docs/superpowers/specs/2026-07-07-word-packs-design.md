# 懒人词包(Word Packs)设计文档

- 日期:2026-07-07
- 状态:已批准,待转实现计划
- 目标平台:macOS + iOS(共用 WordClipKit 与 SwiftData 模型)

## 1. 背景与目标

当前 App 的生词完全依赖用户手动收录(选中取词 / OCR / URL scheme)。**首次运行时词库为空**,新用户没有任何可学的词,冷启动体验差、上手门槛高。

本功能为新用户提供多个按场景/难度预置的「懒人词包」,一键导入即可开始学习。要求:

1. 提供**分级包**(按考试难度)与**场景包**(按主题)两类。
2. 导入的包与用户手动收录的词**隔离**(文件夹式分组),互不干扰。
3. 学习/复习时可**按分组选择**当前要学的词。
4. 词包**离线**提供(随 App 分发,零联网),数据来源合规免费。
5. 全部词包**免费**(与「收集与基础查词永久免费」的现有策略一致)。

## 2. 关键决策(已确认)

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 隔离模型 | **词条归属单一分组**(文件夹模型) | 各组复习进度独立,隔离最彻底。代价:同一 lemma 可能在多组各存一份(可接受,词条很轻)。 |
| 学习/复习范围 | **当前分组单选切换** | 一个选择器(全部 / 手动收录 / 各包),简单直观,符合「一次专注一个场景」。 |
| 词源策略 | **分级包自动生成 + 场景包手工策划** | 分级包从 ECDICT 的 tag 离线生成;场景包 ECDICT 推导不出,需策划词表。 |
| 入口方式 | **首次启动引导 + 长驻入口** | 冷启动引导 + 老用户随时再加包。 |
| 付费分级 | **全部免费** | 词包是降低上手门槛的引导工具,免费最大化激活。 |
| 导入初始状态 | **当作全新词**(`lastReviewedAt = nil`) | 与手动新词一致,自动进新词队列,开箱即学。 |
| 场景包词量 | **300–500 词,以 500 为上限**(非硬指标) | 教学研究:单一主题词表过大会引入语义干扰;质量优先、频次排序,不注水。 |
| 分级包词量 | **按 ECDICT 现有 tag 全量**,不人为截断 | 用户要求「已有的分级包按现有的来做」。 |

## 3. 数据来源与许可

- **内置词典 = ECDICT(MIT 协议)**,`data/ecdict.db` 完整版含约 77 万词条。
- 完整 ECDICT 保留 `tag` 列,含考试分级标签:
  `zk`(中考)/ `gk`(高考)/ `cet4` / `cet6` / `ky`(考研)/ `toefl` / `ielts` / `gre`,
  以及词频 `bnc` / `frq`。
- 注:随 App 分发的裁剪版 `WordClip/Resources/dictionary-en.sqlite` **已丢弃 tag 列**,只留 `freq_rank`。
  因此词包构建必须基于 `data/ecdict.db` 完整库,而非 App bundle 里的裁剪库。
- **分级包**:直接用 tag + 词频离线筛出,零成本、MIT 合规。
- **场景包**:自建普通英文单词清单(无版权问题),释义/音标由 ECDICT 补全。

## 4. 首发词包清单

**分级包(8 个,按 ECDICT tag 全量生成):**
初学者(zk 中考)、高考(gk)、CET4、CET6、考研(ky)、托福(toefl)、雅思(ielts)、GRE(gre)
— 最终以 tag 实际覆盖为准。

**场景包(4 个,手工策划,每包 300–500 词):**
日常生活、旅游娱乐、程序员/技术文档、商务职场

场景词表草案由开发方起草、用户审校。词量以质量与频次优先,300–500 区间,500 为上限,不为凑数注入低频冷僻词。

## 5. 架构设计

### 5.1 数据模型(WordClipKit / Models.swift)

新增 `WordGroup` 模型(遵守现有 CloudKit 建模约束:无 `.unique`,属性有默认值或可选):

```swift
@Model
public final class WordGroup {
    public var id: UUID
    public var name: String          // "手动收录" / "旅游娱乐" / "考研核心"
    public var kind: String          // "manual" | "pack"
    public var packSlug: String?     // 分级/场景包稳定标识(如 "travel"、"cet4");manual 组为 nil
    public var iconSymbol: String?   // SF Symbol 名,用于列表/选择器
    public var sortOrder: Int
    public var createdAt: Date
    // 反向关系可选;为 CloudKit 兼容不设 deleteRule 到 WordEntry(见下)
}
```

`WordEntry` 新增字段:

```swift
public var group: WordGroup?         // 可选关系(CloudKit 兼容);nil 视为"手动收录"兜底
```

**`kind` / `packSlug` 用 String 而非 enum**:与现有模型风格一致(`ReviewMode` 是 enum,但 `platform`、`language` 都用 String),且 CloudKit 对 String 更友好。

### 5.2 去重口径改动

当前去重是「全库按 lemma 唯一」:
- `WordCollector.fetchEntry(lemma:)` — `#Predicate { $0.lemma == lemma }`
- OCR 流程复用同一 upsert

改为「**按 (分组 + lemma) 唯一**」:
- 手动收录始终归入「手动收录」组,在该组内按 lemma 去重。
- 导入包时在**该包的组内**去重。
- 同一 lemma 允许在不同组各存一份独立词条(隔离的必然结果)。

**兜底**:`group == nil` 的存量老词视为「手动收录」组,查询时按此归并 —— 存量用户无需数据迁移即可正常工作。

### 5.3 词包构建脚本(data/)

- 新增 `data/build_wordpacks.py`:
  - **分级包**:读 `ecdict.db`,`WHERE tag LIKE '%<level>%'`,按 `frq`/`bnc` 词频排序,输出全量。
  - **场景包**:读 `data/wordpacks/<slug>.txt`(一行一词),用同一 ECDICT 补全释义/音标/IPA,按词频排序。
  - 两者统一输出 `pack-<slug>.json`。
- 新增 `data/wordpacks/<slug>.txt`:各场景包的策划词表(纯词表,一行一词)。
- 产物 `pack-<slug>.json` 复制到 `WordClip/Resources/wordpacks/`。

**JSON 结构**(每词自带释义,导入时无需再查库):

```json
{
  "slug": "travel",
  "name": "旅游娱乐",
  "icon": "airplane",
  "kind": "pack",
  "version": 1,
  "language": "en",
  "words": [
    {
      "headword": "itinerary",
      "lemma": "itinerary",
      "definition": "n. 行程,路线",
      "definitionEn": "a planned route or journey",
      "phonetic": "aɪˈtɪnərəri"
    }
  ]
}
```

体积:纯文本,几十 KB/包,随 App bundle 分发。

### 5.4 导入器(WordClipKit + App 端落库)

- `WordPackCatalog`(App 端):枚举 `Resources/wordpacks/*.json`,读元信息(slug/name/icon/词数)供 UI 列表。
- `WordPackImporter`:
  1. 解析 `pack-<slug>.json`。
  2. 找到或创建对应 `WordGroup`(kind=pack, packSlug=slug)。
  3. 逐词在**该组内**去重 upsert;新词 `lastReviewedAt = nil`(→ 全新词)。
  4. **幂等**:重复导入同一包只补差集,不重复建组、不重复建词。
- **已导入判定**:该 slug 的组存在且词数 > 0。

纯解析/去重逻辑尽量放 WordClipKit 以便单测;SwiftData 落库在 App 端薄封装。

### 5.5 学习/复习分组切换(StudySession)

当前 `fetchAll()` 拉全库,`buildRound()` / `refreshStats()` 基于全库。改为**按当前选中组过滤**:

- 新增 `selectedGroupID: UUID?`(`nil` = 全部组混学),持久化到 UserDefaults 键 `study.selectedGroup`。
- `fetchAll()` 增加分组谓词;`refreshStats()` 只统计当前组。
- **SM-2 算法、选词规则(复习优先 → 新词填充 → 老词兜底 → 交错)完全不动**,仅把候选集从「全库」缩到「当前组」。

### 5.6 UI

- **首次启动引导** `WordPackWelcomeView`:库为空时呈现,网格列出所有包(名称+图标+词数),可多选勾选 → 一键导入 → 进入学习;可「跳过」。
- **长驻入口** `WordPackBrowserView`:主界面/设置的「词包」入口,随时再添加未导入的包、查看词数;已导入显示「已添加」。
- **分组选择器** `GroupPicker`(复用组件):StudyView / StatsView 顶部,`全部` + `手动收录` + 各已导入包;选中即切换,选词与覆盖率随之只针对该组。

## 6. 文件改动汇总

**新增:**
- `WordClipKit/Sources/WordClipKit/Models/Models.swift` — `WordGroup` 模型
- `WordClipKit/Sources/WordClipKit/Pack/WordPackImporter.swift` — 解析 + 去重(可测)
- `WordClip/Services/WordPackCatalog.swift` — 读 bundle 清单
- `WordClip/Views/WordPackWelcomeView.swift` — 首启引导
- `WordClip/Views/WordPackBrowserView.swift` — 长驻词包浏览
- `WordClip/Views/GroupPicker.swift` — 分组选择器组件
- `data/build_wordpacks.py` — 词包构建脚本
- `data/wordpacks/*.txt` — 场景包策划词表
- `WordClip/Resources/wordpacks/pack-*.json` — 打包产物

**改动:**
- `WordEntry`(+group 关系)
- `WordClipApp.swift` 的 `Schema`(+WordGroup.self);首启逻辑
- `WordCollector`(去重加组;手动词归入手动组)
- OCR 收录去重(同上口径)
- `StudySession`(分组过滤 + selectedGroupID)
- `StudyView` / `StatsView`(加分组选择器)

## 7. 测试策略

- **WordPackImporter**(WordClipKit 单测):解析 JSON、组内去重、幂等重导、新词初始状态。
- **去重口径**:同一 lemma 在手动组与包组各存一份;同组内重复不新建。
- **StudySession 分组过滤**:选中组只出该组的词;`全部` 混学;stats 只统计当前组。
- **构建脚本**:`verify` 抽查各包词数、词频排序、释义补全率。

## 8. 非目标(YAGNI)

- 不做用户自定义分组 / 手动移动词条到其他组(首版只有「手动收录 + 预置包」)。
- 不做多选分组混学(单选切换即可)。
- 不做词包的在线更新 / 下载(离线随 App 分发)。
- 不做词包付费(全部免费)。
- 不改 SM-2 算法本身。

## 9. 迁移与兼容

- `group` 可选 + `nil` 兜底为手动组 → 存量用户老词无需数据迁移。
- 遵守现有 CloudKit 建模约束,为将来 iCloud 同步(现为预留 UI)保留兼容。
