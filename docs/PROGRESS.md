# WordClip 开发进度

> 记录当前已实现的功能与计划中的开发。产品规划见 [PLAN.md](PLAN.md),架构决策见 [ARCHITECTURE.md](ARCHITECTURE.md),用户用法见 [../HELP.zh-Hans.md](../HELP.zh-Hans.md)（英文 [../HELP.md](../HELP.md)、繁體 [../HELP.zh-Hant.md](../HELP.zh-Hant.md)）。

---

## 已实现功能

### 工程与基建
- 多平台 Xcode 工程(macOS + iOS/iPadOS),xcodegen 管理,可跨机器重新生成。
- `WordClipKit` Swift Package 承载平台无关核心:模型、词库、复习算法、导入导出、统计。
- SwiftData 数据模型 `WordEntry` / `CollectSource` / `ReviewLog` / `WordGroup`,纯本地存储,预留 CloudKit 切换接口(遵守 CloudKit 建模约束)。
- String Catalog 三语 `en`(源语言)+ `zh-Hans` + `zh-Hant`:App 一份 `Localizable.xcstrings`、
  `WordClipKit` 一份(`bundle: .module`)、`InfoPlist.xcstrings` 一份。界面文案全部走
  `String(localized:)`,`scripts/check-localization.sh` 在 CI 里守住覆盖率与硬编码。
- App 分类与显示名已配置。
- `WordClipKit` 单元测试 70 条,GitHub Actions CI 跑 `swift test`。

### 收集
- **macOS 全局收词**:`KeyboardShortcuts` 注册热键(默认 `⌥⌘C`,可改),经 Accessibility 直读选中文本(`SelectionReader`),不动剪贴板;结果用悬浮 HUD(`CollectHUD`)反馈,不进通知中心。
- **OCR 收词(Pro,macOS)**:独立热键(默认 `⌥⌘O`)→ 全屏框选(`RegionSelector`)→ ScreenCaptureKit 截图(`ScreenCapturer`)→ Vision 识别(`ScreenOCR`)→ 内置词典校验 + 滤除短大写噪声 → 选词面板(`OCRWordPicker`)多选收录。分词纯逻辑 `WordTokenizer` 在 Kit 内并单测。
- 收词开关可全局启用/停用(设置页 + 状态栏),热键注册一次、启用/停用切换。
- **状态栏图标**(`MenuBarExtra` + `MenuBarMenuView`):今日概览(生词本 / 待复习 / 新词)、启用/停用选中收词、打开主窗口、打开设置、退出。图标常亮/变暗指示收词是否启用。
- **关窗隐藏 Dock 图标**(`DockVisibility`):⌘W / 红灯被接管成 `orderOut` 而非真关(单例 `Window` 场景真关会被 SwiftUI 拆掉,重开丢侧边栏选中项和滚动位置),窗口全收起后切 `NSApp.setActivationPolicy(.accessory)`。可见窗口只认显式登记过的主窗口和设置窗口,不去过滤 `NSApp.windows`——HUD / OCR 面板 / 截屏遮罩 / MenuBarExtra 宿主都是 NSWindow,按类型和 level 猜会漏判。设置页「通用」可关,默认开。
- **macOS 直发打包**(`scripts/package-release.sh`):Release 通用二进制 + 自签名证书 + DMG(含 `Applications` 软链和三语首次运行说明)。走 `ReleaseDirect` 配置,只给 macOS target 定义 `WORDCLIP_DIRECT_DISTRIBUTION`,换用 `UnlockedEntitlement` 把 Pro 放开——直发拿不到 App Store收据,不放开则 OCR 取词和词典导入永久锁死且付费墙无交易可完成。脚本用 `strings` 断言该标志确实生效,否则直接失败。编译条件**不能**从 xcodebuild 命令行传:命令行是全局的,会替换掉 SwiftPM 依赖自己 `.define` 的条件,GRDB 会编不过。App Store 构建仍是不带该标志的 `Release`。
- **URL Scheme**:`wordclip://collect?word=X`。macOS 经 `AppDelegate` 统一处理,后台收录不新开/闪烁窗口;iOS 走 `onOpenURL`。
- **收录去重**:按归一化词元合并,记录来源与时间。
- iOS/iPad 手动输入或剪贴板粘贴添加(`AddWordView`)。

### 懒人包
- **两类离线懒人包**:分级包(初学者/高考/CET4/CET6/考研/托福/雅思/GRE,由 `data/build_wordpacks.py` 从完整 ECDICT 的 tag 列离线生成)+ 场景包(日常/旅游/技术/商务,手工策划词表 + ECDICT 补全释义,每包 300–500 词)。产物 `pack-*.json` 以 folder reference 随 App 分发(`project.yml`),`WordPackCatalog` 读取。
- **文件夹式分组隔离**:`WordGroup`(kind=manual/pack)。词条单一归属,去重按「分组 + lemma」;手动/OCR 收录归入「手动收录」组,导入包归入各自包组。`WordPackStore` 幂等导入(重复导入只补差集),导入词按「全新词」入队。存量老词(group=nil)启动时一次性迁移到手动组。
- **分组学习**:`StudySession.selectedGroupID` 按分组过滤候选集(nil=全部混学),复习页顶部 `GroupPicker` 切换;SM-2 算法与选词规则不变。
- **入口**:首启空库自动弹懒人包引导(每次启动空库即弹);生词本 / 复习页工具栏「懒人包…」长驻入口随时补导入。全部免费。

### 词典与查词
- 内置 ECDICT 约 5 万词离线库,`GRDBDictionaryProvider`(GRDB SQLite),首启从 bundle 拷到 App Support 只读打开。
- **词形还原**:利用 ECDICT `exchange` 列把变形词(如 `brought`)回退到原型查询。
- **复合词库**(`CompositeDictionaryProvider`):内置 + 用户导入,按优先级 lookup,suggest 合并去重。
- **自定义词典导入**(`DictionaryImporter` + `DictionaryStore`):CSV(逗号/制表符、引号转义)与 ECDICT 结构 SQLite,叠加共存,元数据存 UserDefaults、文件存 App Support,可启用/停用/删除/排序;App 内「如何导入词典」说明页(`DictionaryImportGuideView`)讲清用途与格式。
- **释义结构化**(`DefinitionFormatter`):按词性分行、学科标记、中英分区,卡片与详情共用。

### 生词本
- 三栏布局(macOS / iPad):导航 → 列表 → 详情,`WordSelection` 统一选中态,原生单击选中、双击/回车打开。
- **搜索**:输入防抖 + `#Index` + 结果缓存;生词本匹配优先,下方列出词典中未收录的匹配词,点击预览释义并一键收录。
- **按懒人包过滤 + 移除懒人包**:已导入懒人包后工具栏出现 `GroupPicker`(全部/手动收录/各懒人包);过滤到某个懒人包组时,工具栏出现「移除此懒人包」→ 确认弹窗(显示待删词数)→ 删该组词条 + 复习日志(`WordPackRemover`,Kit 内单测)+ 分组本身,懒人包恢复「未导入」可再导入。手动组不可移除。
- **排序**:收录时间 / 字母 / 熟悉度,工具栏菜单切换,`AppStorage` 记忆。
- 收藏、TTS 朗读(`Speaker` / `AVSpeechSynthesizer`)、释义修复(重新查词回填)、删除。
- 新收录词若词典未就绪导致释义缺失,进入生词本自动补全。
- **键盘快捷键**(macOS / 接键盘的 iPad):`⌘1–4` 切换导航、`⌘F`/`⌘K` 搜索、`⌘N` 添加、`⌘L` 朗读、`⌘D` 收藏、`⌘R` 修复、`⌘⌫` 删除、`↑/↓` 切换词条、`⌘/` 速查表(`ShortcutCheatSheet`)。
- 去除所有默认蓝色焦点框。
- iOS/iPad 滑动 + 点击删除免确认弹窗。

### 复习
- SM-2 间隔重复(`SM2Engine`,封装为 `ReviewEngine` 协议可换 FSRS),`StudySession` 驱动。
- 翻卡看释义,`空格` 翻面、`←`不认识 / `→`认识,翻面不可逆。
- 生词本徽标区分新词(绿)/ 待复习(橙)。
- 本地通知每日复习提醒(`NotificationService`,按需申请权限)。

### 统计与数据
- 统计面板(`StatsCalculator` + `StatsView`):总词数、待复习、新词、掌握率。
- JSON 备份导入 / 导出(`BackupService` + `WordBackup` + `WordBackupDocument`):只导出**手动收录**组的词(懒人包词可重新导入、不进备份),导入固定归入手动组、按单词智能合并、不覆盖学习进度。两端语义对称,避免备份往返展平分组。

### 帮助与说明
- **App 内使用帮助**(`HelpView`):原生分区面板(核心概念 / 收词 / 添加查词 / 复习原理 / 数据与 Pro / FAQ),中英双语。macOS 从「帮助」菜单、两端从设置页「使用帮助」唤出;复用 `ShortcutCheatSheet` 的通知 + sheet 模式。
- **复习原理提示**:复习页 idle 态展示 SM-2 一句话说明(认识拉长间隔 / 不认识重置),附「了解更多」直达帮助页复习原理区。

---

## 计划中功能

### 付费(代码侧已实装,待账号验证)
- **收费政策已定**:一次性购买 · 终身买断(不做订阅)。Pro 权益 = OCR 收词 + 词库导入(iCloud 同步为规划中,未实装)。详见 [PLAN.md §5](PLAN.md)。
- Paywall UI(**单档「终身买断」**,含「恢复购买」)。
- 免费 / Pro 功能闸门统一走 `entitlement.isPro`;DEBUG=`MockEntitlement`、Release=`StoreKitEntitlement`,经 `AppEntitlement` 别名切换。
- StoreKit 2 内购(Non-Consumable)已实装,`.storekit` 配置本地跑通购买/恢复(无需付费账号)。

### iCloud 同步(先预留 UI,功能待账号)
- 设置页放置同步开关 / 状态占位 UI(无账号阶段不落地真实同步)。
- 待账号:配置 CloudKit 容器,开启 SwiftData CloudKit 集成(主要改 `ModelConfiguration`),多设备同步与冲突处理(复习进度取更靠前者)。

### 内购上线验证(待 Apple 付费开发者账号)
- `StoreKitEntitlement` 已实装并在 Release 生效;剩 App Store Connect 配置商品(ID `xyz.phpz.WordClip.pro.lifetime`)+ 真机/沙盒购买与恢复验证。见 [RELEASE-iOS.md](RELEASE-iOS.md)。
- 申请 Small Business Program(15% 抽成,仅 App Store 侧)。

### 在线词典服务(Pro)
- 通过在线服务直接检索 / 导入扩展词典,而非仅导入本地准备好的文件。
- 复用 `DictionaryProvider` / `CompositeDictionaryProvider` 抽象叠加;待定后端形态与词源合规,本地文件导入作为兜底保留。
- **词源授权**:内置 ECDICT 数据授权风险与可商用替代词源调研见 [DICTIONARY-LICENSING.md](DICTIONARY-LICENSING.md)。

### 收集增强
- iOS Share Extension:从系统分享菜单收词。

### 复习增强
- 更多测试模式:中→英拼写、听音辨义。

### 未来
- **AI 增强**:释义 / 例句 / 词根讲解(`AIProvider` 协议已定义,当前为 `NoopAIProvider` 占位)。
- **多语言学习内容**:把英语专用逻辑(分词、词库、TTS、复习参数)收敛进 `LanguagePack`,用日语跑通最小验证,通过 build configuration 产出语言变体。
