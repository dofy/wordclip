# WordClip 开发进度

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
