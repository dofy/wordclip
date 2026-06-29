# WordClip 开发进度

> 按里程碑倒序记录，最新在上。规划详见 [PLAN.md](PLAN.md)。
> 版本号与 git tag 对应关系见[设计文档](superpowers/specs/2026-06-29-progress-tracking-design.md)。

---

## [M0] 项目骨架 + i18n 基建

**状态**：✅ 完成
**完成日期**：2026-06-29
**对应 git tag**：v0.1.0

### 完成内容

- 搭建多平台 Xcode 工程（macOS + iOS），使用 xcodegen 管理，可跨机器重新生成
- 抽出 `WordClipKit` Swift Package，分离核心逻辑与 UI
- SwiftData 数据模型：`WordEntry`、`CollectSource`、`ReviewLog`，纯本地配置，预留 CloudKit 切换接口
- 实现 `SM2Engine` 间隔重复算法（ReviewEngine 协议）
- 实现 `GRDBDictionaryProvider` 离线词库接口（DictionaryProvider 协议）
- 实现 `EnglishPack` 语言包（LanguagePack 协议）
- 实现 `EntitlementProvider` 协议 + `MockEntitlement`（Pro 开关）
- 实现 `AIProvider` 协议 + `NoopAIProvider` 预留接口
- 建立 String Catalog（`Localizable.xcstrings`），配置 zh-Hans + en，覆盖所有界面文案
- 搭基础导航骨架：macOS NavigationSplitView / iOS TabView
- 空状态视图、设置页骨架、Debug 下 Pro 开关
- GitHub Actions CI：`swift test` 自动跑单元测试
- 单元测试 12 条，全部通过（SM2Engine 4 条 / EnglishPack 3 条 / MockEntitlement 4 条）

### 当前停在

> M0 完成。`WordClip.xcodeproj` 已可在 Xcode 打开，iOS/macOS 模拟器均可运行空壳 App。
> 词库查词（M1）尚未接入，`GRDBDictionaryProvider` 已写好但 SQLite 文件需要打包进 App bundle。

### 下一步（M1 启动清单）

1. 在 `data/` 运行 `python3 build_dictionary.py --no-download --top 50000` 重新生成 `dictionary-en.sqlite`
2. 将 `dictionary-en.sqlite` 拖入 Xcode 工程的 Resources（macOS + iOS target 都勾选）
3. 在 `WordClipApp.swift` 初始化 `GRDBDictionaryProvider`，通过 environment 注入
4. 实现查词 UI：搜索栏 + 结果卡片（音标 / 释义 / TTS 朗读按钮）
5. 接入 `AVSpeechSynthesizer` TTS 朗读
6. `WordListView` 点击词条跳详情页，详情页展示词库查询结果

### 备注

- `*.xcodeproj/` 不入库，换电脑后运行 `xcodegen generate` 重新生成（需先 `brew install xcodegen`）
- GRDB 7.5.0 已通过 `Package.resolved` 锁定版本
- macOS entitlement 暂只开 App Sandbox + 文件读写；Accessibility 权限 M2 再启用

---

## [Pre-M0] 项目初始化 + 词库构建

**状态**：✅ 完成
**完成日期**：2026-06-29
**对应 git tag**：—

### 完成内容

- 创建 GitHub 仓库 `dofy/wordclip`
- 确立技术栈与架构决策（详见 ARCHITECTURE.md）
- 确定收费方案：Freemium + StoreKit 2，免费/Pro 功能边界
- 编写词库构建脚本 `data/build_dictionary.py`：ECDICT → SQLite，50,000 词 / 11 MB
- 建立文档体系：PLAN.md / ARCHITECTURE.md / PROGRESS.md

### 当前停在

> 已完成，进入 M0。

---

<!-- 后续里程碑在此上方追加 -->


> 按里程碑倒序记录，最新在上。规划详见 [PLAN.md](PLAN.md)。
> 版本号与 git tag 对应关系见[设计文档](superpowers/specs/2026-06-29-progress-tracking-design.md)。

---

## [Pre-M0] 项目初始化 + 词库构建

**状态**：✅ 完成
**完成日期**：2026-06-29
**对应 git tag**：— （正式里程碑从 M0 开始打 tag）

### 完成内容

- 创建私有 GitHub 仓库 `dofy/wordclip`
- 确立技术栈：SwiftUI 多平台 + SwiftData + CloudKit + `WordClipKit` Swift Package
- 确定收费方案：Freemium + StoreKit 2 订阅，Apple 生态内起步，零自建后端
- 制定免费 / Pro 功能边界（收集查词永久免费，同步/无限/AI 为付费点）
- 完成所有关键技术决策并落入 `docs/ARCHITECTURE.md`
- 编写 `data/build_dictionary.py`：ECDICT → 精简 SQLite，支持 `--top N` 按词频截取
- 验证词库构建：50,000 词 / 11 MB，词频排序正确（`the`=rank1，`apple`=rank2446）
- 建立文档体系：PLAN.md（规划）+ ARCHITECTURE.md（架构决策）+ PROGRESS.md（本文件）

### 当前停在

> 文档与词库构建脚本已就绪。**Xcode 正在下载中**，下载完成后进入 M0。

### 下一步（M0 启动清单）

1. 确认 Xcode 安装完成（`xcodebuild -version` 验证）
2. 在 `wordclip/` 根目录创建 Xcode 多平台工程（macOS + iOS 双 target）
3. 新建 `WordClipKit` Swift Package，放在工程内或同级目录
4. 定义 SwiftData 模型（`WordEntry`、`CollectSource`、`ReviewLog`），纯本地配置
5. 建立 String Catalog（`.xcstrings`），配置 `zh-Hans` + `en`
6. 搭基础导航骨架（TabView / NavigationSplitView）
7. 配置 GitHub Actions CI（`swift test` 跑 Kit 单测）
8. 模拟器运行验证，切换系统语言检查 i18n

### 备注

- 暂无 Apple 付费开发者账号，CloudKit 相关 entitlement 暂不配置
- `data/ecdict.db`（源库）和 `data/dictionary-en.sqlite`（产物）在本地，不入 git
- 下次开发前运行 `python3 data/build_dictionary.py --no-download --top 50000` 可重新生成词库

---

<!-- 后续里程碑在此上方追加 -->
