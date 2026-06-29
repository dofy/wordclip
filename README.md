# WordClip

随时随地收集单词、离线查词、间隔重复测试的多平台单词学习工具。当前面向英语，架构上支持扩展到任意语言。

---

## 当前状态

✅ **M0 · 项目骨架完成** — 可在 Xcode 模拟器运行，单测 12/12 通过
🚧 **进行中：M1 · 离线词库 + 查词**

**下一步**：将 `dictionary-en.sqlite` 打包进 App bundle，接入查词 UI

→ 完整进度见 [docs/PROGRESS.md](docs/PROGRESS.md)

---

## 平台

- **macOS** —— 全局快捷键，一键将任意 App 中选中的单词收录到词典
- **iOS / iPadOS** —— 通过系统分享菜单（Share Extension）收集单词
- 数据通过 **iCloud（CloudKit）** 在设备间自动同步

## 核心特性

- 📥 **快速收集**：桌面全局快捷键 / 移动端分享菜单
- 📖 **离线词库**：内置开源词库（英语用 ECDICT），含音标、释义；读音用系统 TTS
- 🔁 **间隔重复测试**：基于 SM-2 的熟悉度评定（5 级），多种测试模式
- ☁️ **iCloud 同步** + 手动 CSV/JSON 导入导出
- 🌍 **多语言可扩展**：语言包机制，可构建出日语等其他语言的版本
- 🤖 **AI 接口预留**：`AIProvider` 协议先行，未来接入释义/例句/讲解

## 技术栈

SwiftUI（多平台）· SwiftData + CloudKit · Swift Package（`WordClipKit` 共享核心）

## 文档

- [开发进度](docs/PROGRESS.md) — 当前状态、每个里程碑完成内容、下一步
- [开发计划](docs/PLAN.md) — 里程碑规划、功能边界、收费方案
- [架构与关键技术决策](docs/ARCHITECTURE.md)

## 开发环境要求

- macOS + **完整版 Xcode**（仅装 Command Line Tools 无法构建 App）
- Apple Developer 账号（CloudKit / 真机调试 / 上架）

## 状态

🚧 M1 进行中。详见 [docs/PROGRESS.md](docs/PROGRESS.md)。
