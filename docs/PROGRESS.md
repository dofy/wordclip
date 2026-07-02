# WordClip 开发进度

> 记录当前已实现的功能与计划中的开发。产品规划见 [PLAN.md](PLAN.md),架构决策见 [ARCHITECTURE.md](ARCHITECTURE.md),用户用法见 [../HELP.md](../HELP.md)。

---

## 已实现功能

### 工程与基建
- 多平台 Xcode 工程(macOS + iOS/iPadOS),xcodegen 管理,可跨机器重新生成。
- `WordClipKit` Swift Package 承载平台无关核心:模型、词库、复习算法、导入导出、统计。
- SwiftData 数据模型 `WordEntry` / `CollectSource` / `ReviewLog`,纯本地存储,预留 CloudKit 切换接口(遵守 CloudKit 建模约束)。
- String Catalog(`Localizable.xcstrings`)zh-Hans + en,界面文案全部走 `String(localized:)`。
- App 分类与显示名已配置。
- `WordClipKit` 单元测试 44 条,GitHub Actions CI 跑 `swift test`。

### 收集
- **macOS 全局取词**:`KeyboardShortcuts` 注册热键(默认 `⌥⌘C`,可改),经 Accessibility 直读选中文本(`SelectionReader`),不动剪贴板;结果用悬浮 HUD(`CollectHUD`)反馈,不进通知中心。
- 取词开关可全局启用/停用(设置页 + 状态栏),热键注册一次、启用/停用切换。
- **状态栏图标**(`MenuBarExtra` + `MenuBarMenuView`):今日概览(生词本 / 待复习 / 新词)、开始复习、启用/停用取词、打开主窗口 / 设置。
- **URL Scheme**:`wordclip://collect?word=X`。macOS 经 `AppDelegate` 统一处理,后台收录不新开/闪烁窗口;iOS 走 `onOpenURL`。
- **收录去重**:按归一化词元合并,记录来源与时间。
- iOS/iPad 手动输入或剪贴板粘贴添加(`AddWordView`)。

### 词典与查词
- 内置 ECDICT 约 5 万词离线库,`GRDBDictionaryProvider`(GRDB SQLite),首启从 bundle 拷到 App Support 只读打开。
- **词形还原**:利用 ECDICT `exchange` 列把变形词(如 `brought`)回退到原型查询。
- **复合词库**(`CompositeDictionaryProvider`):内置 + 用户导入,按优先级 lookup,suggest 合并去重。
- **自定义词典导入**(`DictionaryImporter` + `DictionaryStore`):CSV(逗号/制表符、引号转义)与 ECDICT 结构 SQLite,叠加共存,元数据存 UserDefaults、文件存 App Support,可启用/停用/删除/排序。
- **释义结构化**(`DefinitionFormatter`):按词性分行、学科标记、中英分区,卡片与详情共用。

### 生词本
- 三栏布局(macOS / iPad):导航 → 列表 → 详情,`WordSelection` 统一选中态,原生单击选中、双击/回车打开。
- **搜索**:输入防抖 + `#Index` + 结果缓存;生词本匹配优先,下方列出词典中未收录的匹配词,点击预览释义并一键收录。
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
- 状态栏"开始复习"可切到复习页并自动开一轮。

### 统计与数据
- 统计面板(`StatsCalculator` + `StatsView`):总词数、待复习、新词、掌握率。
- JSON 备份导入 / 导出(`BackupService` + `WordBackup` + `WordBackupDocument`),按单词智能合并、不覆盖学习进度。

---

## 计划中功能

### 付费墙(骨架,不需账号)
- **收费政策已定**:一次性购买 · 终身买断(不做订阅)。Pro 权益 = iCloud 同步 + 导入导出 + 在线词典功能。详见 [PLAN.md §5](PLAN.md)。
- Paywall UI(**单档「终身买断」**展示)。
- 免费 / Pro 功能闸门统一走 `entitlement.isPro`(`EntitlementProvider` / `MockEntitlement` 已就位)。
- StoreKit 2 `.storekit` Configuration File 本地跑通购买流程(无需付费账号)。

### iCloud 同步(先预留 UI,功能待账号)
- 设置页放置同步开关 / 状态占位 UI(无账号阶段不落地真实同步)。
- 待账号:配置 CloudKit 容器,开启 SwiftData CloudKit 集成(主要改 `ModelConfiguration`),多设备同步与冲突处理(复习进度取更靠前者)。

### 真实内购(待 Apple 付费开发者账号)
- StoreKit 2 一次性内购(Non-Consumable),`StoreKitEntitlement` 替换 mock,UI 不变。
- 申请 Small Business Program(15% 抽成)、真机与沙盒购买测试。

### 在线词典服务(Pro)
- 通过在线服务直接检索 / 导入扩展词典,而非仅导入本地准备好的文件。
- 复用 `DictionaryProvider` / `CompositeDictionaryProvider` 抽象叠加;待定后端形态与词源合规,本地文件导入作为兜底保留。

### 收集增强
- iOS Share Extension:从系统分享菜单收词。

### 复习增强
- 更多测试模式:中→英拼写、听音辨义。

### 未来
- **AI 增强**:释义 / 例句 / 词根讲解(`AIProvider` 协议已定义,当前为 `NoopAIProvider` 占位)。
- **多语言学习内容**:把英语专用逻辑(分词、词库、TTS、复习参数)收敛进 `LanguagePack`,用日语跑通最小验证,通过 build configuration 产出语言变体。
