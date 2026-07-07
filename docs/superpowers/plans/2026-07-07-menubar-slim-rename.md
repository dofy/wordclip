# 状态栏菜单精简 + 「词包」改名「懒人包」 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 状态栏菜单砍到 4 块(概览/收词开关/打开主窗/退出);用户可见的中文「词包」统一改「懒人包」。

**Architecture:** 纯 SwiftUI 文案 + 菜单结构调整,无 Kit / 业务逻辑改动。只改用户可见中文 defaultValue 与文档;不改代码标识符、通知名、String Catalog key 名、英文文案、WordGroup 数据。

**Tech Stack:** SwiftUI(多平台)· String Catalog(手动管理,sparse——多数文案仅存在于源码 defaultValue,未进 catalog)。

## Global Constraints

- Swift 6,macOS 15+ / iOS 18+。
- **只改中文** defaultValue 与中文文档;**英文文案(en)不动**——「懒人包」是中文表述,英文 "Word Pack" 已达意。
- **不改** 代码标识符(`WordPackDTO/Store/Remover/Catalog/BrowserView/Importer`)、通知名(`showWordPacks`)、String Catalog **key 名**(`menu.wordpacks`/`help.section.packs`/`wordlist.removePack.*`/`packs.*`)——只改 key 的**值**。
- **不改** `WordGroup.name` 数据、`kindPack="pack"`、`packSlug` 等内部标识。
- catalog 手动管理:唯一 zh-Hans 值含「词包」的 key 是 `dictguide.what.body`;其余「词包」文案都在源码 defaultValue、未进 catalog——改源码 defaultValue 即可(catalog 无对应条目时运行时用 defaultValue)。
- 无 Kit 改动、无 `project.yml` 改动。

---

## File Structure

- `WordClip/Views/MenuBarMenuView.swift` — 删 3 个菜单项(开始复习/词包/设置)。
- `WordClip/Views/MainViews.swift` — 移除按钮/确认/工具栏入口的中文「词包」→「懒人包」(defaultValue + 注释)。
- `WordClip/Views/StudyView.swift` — 复习页工具栏「词包…」→「懒人包…」。
- `WordClip/Views/HelpView.swift` — 懒人包分区文案。
- `WordClip/Views/WordPackBrowserView.swift` — 引导/浏览页展示文案。
- `WordClip/Views/DictionaryImportGuideView.swift` — 正文提到「词包」处。
- `WordClip/Resources/Localizable.xcstrings` — `dictguide.what.body` 的 zh-Hans 值。
- `HELP.md` / `README.md` / `docs/PROGRESS.md` / `docs/ARCHITECTURE.md` — 用户向「词包」→「懒人包」。

---

### Task 1: 状态栏菜单精简

**Files:**
- Modify: `WordClip/Views/MenuBarMenuView.swift`

**Interfaces:**
- Consumes: 现有 `MenuBarMenuView` body。
- Produces: 精简后的菜单(概览 → 分隔 → 收词开关 → 分隔 → 打开 WordClip → 退出)。

- [ ] **Step 1: 删「开始复习」按钮及其后的 Divider**

`WordClip/Views/MenuBarMenuView.swift`,删除这一整段(第 23–35 行附近):

```swift
        // 开始复习（有到期或新词时）
        Button {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .startReviewFromMenuBar, object: nil)
        } label: {
            Label(String(localized: "menubar.review", defaultValue: "开始复习"),
                  systemImage: "play.fill")
        }
        .keyboardShortcut("r", modifiers: [.command])
        .disabled(due == 0 && newWords == 0)

        Divider()
```

删除后,概览 `Text` 之后直接接「取词开关」上方的 `Divider()`。

- [ ] **Step 2: 删「词包…」按钮**

删除这一整段(第 59–64 行附近):

```swift
        // 打开词包浏览(长驻入口)
        Button(String(localized: "menu.wordpacks", defaultValue: "词包…")) {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
            NotificationCenter.default.post(name: .showWordPacks, object: nil)
        }
```

- [ ] **Step 3: 删「设置…」按钮**

删除这一整段(第 66–71 行附近):

```swift
        // 打开设置
        Button(String(localized: "menubar.settings", defaultValue: "设置…")) {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)
```

删除后「打开 WordClip」按钮之后直接接「退出」上方的 `Divider()`。最终 body 结构:概览 Text → Divider → 收词开关 Button → Divider → 打开 WordClip Button → Divider → 退出 Button → refreshStats 的 Color.clear。

- [ ] **Step 4: 构建 macOS**

Run: `cd /Users/seven/Works/github/wordclip && xcodebuild -project WordClip.xcodeproj -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -3`
Expected: `** BUILD SUCCEEDED **`

> 注:删除后 `menubar.review` / `menubar.settings` 两个 key 在本文件不再引用。`menubar.settings` 可能全仓再无引用(MenuBar 是唯一处)、`menubar.review` 亦然——但**本任务不删 catalog key**(留给最终审查统一处理,避免与 Task 3 的 catalog 改动交叉)。`menu.wordpacks` 仍被 MainViews/StudyView 引用,不受影响。

- [ ] **Step 5: 运行时冒烟**

Run:
```bash
osascript -e 'quit app "WordClip"' 2>/dev/null; sleep 1
APP="$(ls -d ~/Library/Developer/Xcode/DerivedData/WordClip-*/Build/Products/Debug/WordClip.app | head -1)"; open "$APP" && sleep 3 && (pgrep -x WordClip >/dev/null && echo "RUNNING OK" || echo "NOT RUNNING")
```
Expected: `RUNNING OK`。(菜单内容需人工点状态栏图标确认,subagent 只需确认不崩。)之后 `osascript -e 'quit app "WordClip"'`。

- [ ] **Step 6: 提交**

```bash
git add WordClip/Views/MenuBarMenuView.swift
git commit -m "feat: 状态栏菜单精简为 4 块(概览/收词开关/打开主窗/退出)"
```

---

### Task 2: 源码「词包」→「懒人包」(中文文案)

**Files:**
- Modify: `WordClip/Views/MainViews.swift`
- Modify: `WordClip/Views/StudyView.swift`
- Modify: `WordClip/Views/HelpView.swift`
- Modify: `WordClip/Views/WordPackBrowserView.swift`
- Modify: `WordClip/Views/DictionaryImportGuideView.swift`
- Modify: `WordClip/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: 各视图现有 `String(localized:defaultValue:)` 文案。
- Produces: 中文展示文案统一为「懒人包」。key 名与 en 不变。

- [ ] **Step 1: MainViews.swift — 改 4 处 defaultValue + 相关注释**

逐处精确替换(key 名不动,只改 defaultValue 中文):

- 第 299 行:`defaultValue: "移除此词包"` → `defaultValue: "移除此懒人包"`
- 第 310 行:`defaultValue: "词包…"` → `defaultValue: "懒人包…"`
- 第 362 行:`defaultValue: "移除词包"` → `defaultValue: "移除此懒人包"`
- 第 384 行:`defaultValue: "移除「\(selectedGroup?.name ?? "")」词包？"` → `defaultValue: "移除「\(selectedGroup?.name ?? "")」懒人包？"`
- 第 390 行:`defaultValue: "将删除该词包的 \(count) 个单词及其复习进度，可随时重新导入。"` → `defaultValue: "将删除该懒人包的 \(count) 个单词及其复习进度，可随时重新导入。"`

注释同步(可选但保持一致):第 306 行 `// 词包(懒人包):…` → `// 懒人包:…`;第 290/294 行注释里的「词包」→「懒人包」。

- [ ] **Step 2: StudyView.swift — 复习页工具栏入口**

第 29 行:`defaultValue: "词包…"` → `defaultValue: "懒人包…"`

- [ ] **Step 3: HelpView.swift — 懒人包分区文案**

- 第 145 行:`defaultValue: "词包(懒人包)"` → `defaultValue: "懒人包"`
- 第 147 行:`defaultValue: "预置词包"` → `defaultValue: "预置懒人包"`
- 第 155 行:`defaultValue: "移除词包"` → `defaultValue: "移除懒人包"`
- 第 157 行:`defaultValue: "在生词本工具栏把分组过滤到某个词包,点「移除此词包」并确认,即可删掉该包的全部单词与复习进度,之后仍可重新导入。"` → 把两处「词包」改「懒人包」:`"在生词本工具栏把分组过滤到某个懒人包,点「移除此懒人包」并确认,即可删掉该包的全部单词与复习进度,之后仍可重新导入。"`

（若同节其它 item 正文含「词包」,一并改「懒人包」；以实际 Read 到的为准。）

- [ ] **Step 4: WordPackBrowserView.swift — 引导/浏览页**

- 第 22 行:`defaultValue: "选择词包,快速开始"` → `defaultValue: "选择懒人包,快速开始"`
- 第 23 行:`defaultValue: "词包"` → `defaultValue: "懒人包"`

- [ ] **Step 5: DictionaryImportGuideView.swift — 正文提到词包处**

第 60 行:`…想批量添加学习词条,请用「词包」。` → `…想批量添加学习词条,请用「懒人包」。`

- [ ] **Step 6: xcstrings — dictguide.what.body 的 zh-Hans 值**

`dictguide.what.body` 是唯一 zh-Hans 值含「词包」的 catalog key(catalog 值会覆盖源码 defaultValue,故必须同步)。用 Python 精确改其 zh-Hans value:

```bash
cd /Users/seven/Works/github/wordclip && python3 - <<'PY'
import json
p='WordClip/Resources/Localizable.xcstrings'
d=json.load(open(p))
k='dictguide.what.body'
u=d['strings'][k]['localizations']['zh-Hans']['stringUnit']
u['value']=u['value'].replace('「词包」','「懒人包」')
json.dump(d, open(p,'w'), ensure_ascii=False, indent=2)
json.load(open(p))  # 验证合法
print("zh-Hans now:", u['value'])
PY
```
Expected: 输出含「请用「懒人包」。」，JSON 合法。（en 不动。）

- [ ] **Step 7: 构建 macOS + iOS**

Run: `cd /Users/seven/Works/github/wordclip && xcodebuild -project WordClip.xcodeproj -scheme WordClip-macOS -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -2`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild -project WordClip.xcodeproj -scheme WordClip-iOS -configuration Debug -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "BUILD SUCCEEDED|BUILD FAILED|error:" | tail -2`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: 确认源码无残留用户可见「词包」**

Run: `grep -rn "词包" WordClip/Views/ | grep "defaultValue\|Text(\|title:"`
Expected: 无输出(所有用户可见 defaultValue 已改「懒人包」;若有输出,补改)。注释里的「词包」可留可改,不阻塞。

- [ ] **Step 9: 提交**

```bash
git add WordClip/Views/MainViews.swift WordClip/Views/StudyView.swift WordClip/Views/HelpView.swift WordClip/Views/WordPackBrowserView.swift WordClip/Views/DictionaryImportGuideView.swift WordClip/Resources/Localizable.xcstrings
git commit -m "feat: 用户可见「词包」中文统一改「懒人包」(英文/key 名/类型名不动)"
```

---

### Task 3: 文档「词包」→「懒人包」

**Files:**
- Modify: `HELP.md` / `README.md` / `docs/PROGRESS.md` / `docs/ARCHITECTURE.md`

**Interfaces:**
- Consumes: 四份文档现有「词包」表述。
- Produces: 用户向「词包」统一「懒人包」。

- [ ] **Step 1: 各文档替换「词包」→「懒人包」**

用户向文档(HELP.md / README.md)里所有「词包」→「懒人包」,包括标题「### 词包(懒人包)」→「### 懒人包」。

docs/PROGRESS.md / docs/ARCHITECTURE.md 里作为**功能名**的「词包」→「懒人包」(如「### 词包(懒人包)」「两类离线词包」);但**代码标识符引用**保持原样(`WordPackStore`/`WordPackRemover`/`WordPackCatalog`/`WordPackDTO`/`build_wordpacks.py`/`pack-*.json` 等英文标识不变)。

建议用 sed 批量后人工核对(避免误伤英文标识符——中文「词包」不会出现在英文标识符里,sed 安全):

```bash
cd /Users/seven/Works/github/wordclip
sed -i '' 's/词包/懒人包/g' HELP.md README.md docs/PROGRESS.md docs/ARCHITECTURE.md
```

- [ ] **Step 2: 核对无误伤 + 无残留**

Run: `grep -rn "词包" HELP.md README.md docs/PROGRESS.md docs/ARCHITECTURE.md`
Expected: 无输出(全部改「懒人包」)。

Run: `grep -rn "懒人包懒人包\|WordPack懒\|懒人包Store" HELP.md README.md docs/PROGRESS.md docs/ARCHITECTURE.md`
Expected: 无输出(无双重替换/误伤英文标识符)。

- [ ] **Step 3: 提交**

```bash
git add HELP.md README.md docs/PROGRESS.md docs/ARCHITECTURE.md
git commit -m "docs: 用户向「词包」统一改「懒人包」(代码标识符引用不动)"
```

---

## Self-Review

**Spec coverage:**
- 状态栏菜单砍 3 项留 4 块 → Task 1 ✓
- 图标/概览/refreshStats 不动 → Task 1 未触及 ✓
- 源码用户可见「词包」→「懒人包」→ Task 2(MainViews/StudyView/HelpView/WordPackBrowserView/DictionaryImportGuideView 全覆盖,基于 grep 实测清单)✓
- xcstrings 唯一含词包的 dictguide.what.body → Task 2 Step 6 ✓
- 英文不动 / key 名不动 / 类型名不动 → Global Constraints + Task 2 逐处只改中文 ✓
- 文档改名 → Task 3 ✓
- 代码标识符引用在文档里不误改 → Task 3 Step 1 说明 + Step 2 核对 ✓

**Placeholder scan:** 无 TBD/TODO。所有替换给了确切行号 + 前后文本。HelpView Step 3 有「以实际 Read 到的为准」的兜底,但已列出已知全部行,非模糊占位。

**Type consistency:** 全程只改字符串字面量,无类型/签名改动。`menu.wordpacks` key 删 MenuBar 引用后仍被 MainViews/StudyView 用(已 grep 确认),保留;其值在 Task 2 Step 1/2 改为「懒人包…」——注意 MainViews:310 与 StudyView:29 引用**同一 key** `menu.wordpacks`,两处 defaultValue 要一致改「懒人包…」(MenuBar 的第三处已在 Task 1 删除)。

**孤儿 key 提示:** Task 1 删菜单项后 `menubar.review` / `menubar.settings` 可能全仓无引用 → 记入最终审查 triage,不在任务内删(避免与 catalog 改动交叉;且它们未进 catalog、仅源码 defaultValue,删源码引用即自然消失,无孤儿 catalog 条目)。
