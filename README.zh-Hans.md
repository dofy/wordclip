<p align="center"><img src="website/public/app-icon.png" alt="WordClip icon" width="120" /></p>

<h1 align="center">WordClip</h1>

<p align="center"><strong>随手收集，慢慢掌握。</strong></p>

<p align="center"><a href="README.md">English</a> · <strong>简体中文</strong> · <a href="README.zh-Hant.md">繁體中文</a><br />
<a href="https://github.com/dofy/wordclip">GitHub</a> · <a href="https://github.com/dofy/wordclip/issues">Issues</a></p>

<p align="center">
  <img src="https://img.shields.io/badge/Mac-Apple%20Silicon-536b83?style=flat-square" alt="Mac: Apple Silicon" />
  <img src="https://img.shields.io/badge/platforms-macOS%20%7C%20iOS%20%7C%20iPadOS-3c647b?style=flat-square" alt="macOS, iOS and iPadOS" />
  <img src="https://img.shields.io/badge/dictionary-offline-607c68?style=flat-square" alt="Offline dictionary" />
  <img src="https://img.shields.io/badge/review-spaced%20repetition-a67551?style=flat-square" alt="Spaced repetition" />
  <img src="https://img.shields.io/badge/UI-SwiftUI-d66f56?style=flat-square" alt="SwiftUI" />
</p>

[WordClip](https://wordclip.phpz.org) 是一款随时随地收集单词、离线查词、间隔重复复习的多平台单词学习工具。当前面向英语,架构上支持扩展到任意语言。

**平台**:macOS · iOS · iPadOS
**技术栈**:SwiftUI(多平台单一代码库)· SwiftData · Swift Package(`WordClipKit` 共享核心)· GRDB(离线词库)

## 已实现功能

### 收集
- **macOS 全局收词**:任意 App 中选中单词,按快捷键(默认 `⌥⌘C`)一键收录,屏幕弹出 HUD 提示,不打断当前 App。基于 Accessibility 直读选中文本,不改动剪贴板。
- **OCR 收词(Pro)**:按快捷键(默认 `⌥⌘O`)框选屏幕区域,Vision 识别其中单词,经内置词典校验后弹选词面板多选收录。适用于图片 / PDF / 不可选文本。
- **状态栏图标**:查看今日概览、快速启用/停用选中收词、打开主窗口或设置;图标常亮/变暗指示收词是否启用。
- **不占 Dock**:`⌘W` 收起窗口时 Dock 图标一起消失。WordClip 继续在状态栏运行,取词快捷键照常工作,重新打开时窗口和你离开时一样。可在「设置 > 通用」关掉。
- **URL Scheme**:`wordclip://collect?word=<单词>`,可从快捷指令、脚本、其他 App 调用收词。
- **iOS / iPadOS**:手动输入或从剪贴板粘贴添加单词。

### 懒人包
- **两类离线懒人包**:分级包(初学者/高考/CET-4/CET-6/考研/托福/雅思/GRE)+ 场景包(日常生活/旅游娱乐/技术英语/商务职场),全部免费离线。
- **文件夹式隔离**:导入的词与手动收录的词按分组隔离,复习/生词本可按分组过滤,只学某个包或选「全部」混学。
- **移除懒人包**:生词本工具栏过滤到某个懒人包,可一键移除(删该包词条与复习进度),之后仍可重新导入。
- **入口**:空库时每次启动自动引导 + 生词本 / 复习页工具栏随时补导入。

### 词典与查词
- **内置离线词库**:ECDICT 精简版约 5 万词(音标 + 中英释义),GRDB SQLite,随包分发。
- **词形还原**:`brought → bring` 等变形自动归一到原型查词。
- **自定义词典导入**:扩充查词时的释义来源(非添加生词)。支持 CSV 和 ECDICT 结构的 SQLite,多本按优先级叠加,可启用/停用/删除/排序;App 内含格式说明与准备指引。
- **释义结构化**:按词性分行、学科标记(`[计]`/`[化]`)灰字、中英释义分区展示。

### 生词本
- **三栏布局**(macOS / iPad):导航 → 列表 → 详情。
- **搜索**:生词本匹配词优先,下方列出词典中未收录的匹配词,点击预览并一键收录。
- **分组过滤**:已导入懒人包后,工具栏出现分组下拉,可只看某个懒人包 / 手动收录 / 全部。
- **排序**:按收录时间 / 字母 / 熟悉度,记忆上次选择。
- 收藏、TTS 朗读、释义修复、删除。
- **全套键盘快捷键**(macOS / 接键盘的 iPad):导航切换、搜索定位、增删、朗读、收藏等。

### 复习
- **SM-2 间隔重复算法**:翻卡看释义,标记"认识/不认识"——认识拉长下次间隔、不认识重置回明天,自动排程复习。
- 翻面不可逆(防误触),学习时 `空格` 翻面、`←/→` 评分。
- 生词本徽标区分"新词 / 待复习"。
- **本地通知**每日复习提醒。

### 统计与数据
- 统计面板:总词数、待复习、新词、掌握率。
- **JSON 备份导入/导出**:导出手动收录的词(懒人包词可重新导入、不进备份),导入按单词智能合并、不覆盖已有学习进度。

### 付费
- **WordClip Pro 付费墙**:单档「终身买断」页面(权益:OCR 收词、词库导入)。
- **功能闸门**:免费/Pro 边界统一走 `entitlement.isPro`;DEBUG 用 `MockEntitlement`(设置「模拟 Pro」调试),Release 用真实 `StoreKitEntitlement`,经 `AppEntitlement` 别名切换。
- **StoreKit 2 内购(已实装)**:`StoreKitEntitlement`(一次性非消耗型)+ 本地 `.storekit` 配置,Xcode Run 即可测购买/恢复,无需付费账号;上架待 ASC 商品配置 + 真机验证。
- **免费**:收集 + 基础离线查词 + 生词本 + 复习 + 统计 + 导出。**Pro**:OCR 收词、词库导入。

### 其他
- **界面多语言**:English / 简体中文 / 繁體中文(String Catalog,跟随系统语言),界面语言与学习语言相互独立。
- **iCloud 同步预留 UI**:设置页占位开关(真实同步为规划中功能,尚未实装)。
- `WordClipKit` 单元测试 70 条覆盖算法 / 词库 / 导入 / 统计 / 权益 / 懒人包。

---

## 计划中功能

> **收费政策(已定)**:一次性购买 · 终身买断(不做订阅)。**WordClip Pro** 权益:OCR 收词、词库导入(及规划中的 iCloud 同步、在线词典)。收集与基础查词永久免费。详见 [PLAN.md](docs/PLAN.md#5-收费政策已定)。

- **iCloud 同步**:SwiftData + CloudKit 多设备自动同步(已预留设置页 UI,真实同步待实装 + Apple 付费开发者账号)。
- **在线词典服务**:通过在线服务直接检索/导入扩展词典(不止导入本地文件);本地 CSV / SQLite 导入作为兜底保留。
- **iOS Share Extension**:从系统分享菜单收词。
- **更多复习模式**:中→英拼写、听音辨义等(当前为翻卡认识/不认识)。
- **AI 增强**:释义 / 例句 / 词根讲解(`AIProvider` 协议已预留,当前为占位实现)。
- **多语言学习内容**:日语等(当前收词逻辑面向英语)。

---

## 文档

- [使用帮助](HELP.zh-Hans.md) — 面向用户的用法说明、快捷键、词典导入、URL scheme
- [开发进度](docs/PROGRESS.md) — 已实现功能与开发计划
- [开发计划](docs/PLAN.md) — 产品目标、功能边界、收费方案
- [架构与关键技术决策](docs/ARCHITECTURE.md)
- [`website/`](website/README.md) —— 三语产品站，部署在 [wordclip.phpz.org](https://wordclip.phpz.org)

## 开发环境

- macOS + **完整版 Xcode**(仅装 Command Line Tools 无法构建 App)
- `brew install xcodegen`;`*.xcodeproj` 不入库,克隆后运行 `xcodegen generate` 生成工程
- 真机调试 / 分发需 Apple Developer 账号

## 分发路线

- **iOS/iPadOS**:上 App Store。见 [RELEASE-iOS.md](docs/RELEASE-iOS.md)。
- **macOS**:Developer ID + 公证 + 网站分发(**不上 Mac App Store**,以保留原生全局取词——沙盒禁止跨 App 读取选中文本)。详见 [ARCHITECTURE §3.1](docs/ARCHITECTURE.md) 与 [PLAN 分发路线](docs/PLAN.md)。

```bash
./scripts/package-release.sh          # → dist/WordClip-<版本>.dmg
```

脚本构建 Release Apple Silicon（`arm64`）二进制、签名,并打出一个 DMG:App、`Applications` 符号链接,
以及一份三语首次运行说明(Gatekeeper、辅助功能、屏幕录制)。

**这个构建里 Pro 是解锁的。** 直接分发的副本拿不到 App Store 收据,
`StoreKitEntitlement` 会永远判定未购买,OCR 取词和词典导入被锁在付费墙后,而付费墙
也没有能完成的交易。该构建定义 `WORDCLIP_DIRECT_DISTRIBUTION`,换用
`UnlockedEntitlement`;标志万一没生效,脚本会直接失败而不是发出一个功能被锁死的包。
App Store 构建是**不带**这个标志的那个,不受影响。

签名默认用自签名证书 `WordClip Distribution`,所以 macOS 首次启动会拦一次,收到的人
在系统设置里批准一次即可。要备份这张证书并且以后每次构建都用它,否则 macOS 不再把新
版本认作同一个 app,所有人的辅助功能授权都要重授。有 Apple 开发者账号时改传真实身份,
警告就没有了:

```bash
SIGNING_IDENTITY="Developer ID Application: 名字 (TEAMID)" \
  ./scripts/package-release.sh
```

这条路径还会打开硬化运行时和安全时间戳,公证需要这两样。公证本身
(`xcrun notarytool submit` 与 `stapler staple`)还没接。

