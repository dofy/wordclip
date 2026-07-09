# iOS 上架清单（App Store）

> 目标:把 WordClip iOS 版提交到 App Store 审核并发布。
> 代码/配置侧已就绪(见「就绪状态」);本清单是**你在 Apple 门户 / Xcode 里手动操作**的分步指南。
> 最后更新:2026-07-09 · 首个发布版本:**1.0.0 (build 1)**

---

## 关键常量(全程对齐,勿写错)

| 项 | 值 |
|---|---|
| Bundle ID | `xyz.phpz.WordClip` |
| Apple Team ID | `5GS5X3MD6G` |
| 内购商品 ID(终身买断) | `xyz.phpz.WordClip.pro.lifetime` |
| 内购类型 | 非消耗型(Non-Consumable) |
| 参考价 | ¥28 / $?（`.storekit` 里 28.00,以 ASC 定价档为准) |
| App 分类 | 教育(Education) |
| 版本 / 构建号 | `1.0.0` / `1` |
| 支持平台 | iPhone + iPad(TARGETED_DEVICE_FAMILY 1,2) |
| 最低系统 | iOS 18.0 |

> ⚠️ 内购商品 ID **必须**与代码 `StoreKitEntitlement.lifetimeProductID` 及 `WordClip.storekit` 完全一致,否则线上拉不到商品、购买失败。

---

## 就绪状态(代码侧,已完成 ✅)

- ✅ 真实 StoreKit 付费:Release 构建走 `StoreKitEntitlement`(购买/恢复/交易监听齐全),DEBUG 走 Mock。见 `WordClip/App/AppEntitlement.swift`。
- ✅ Paywall 含「恢复购买」按钮(审核硬性要求)。
- ✅ 隐私清单 `PrivacyInfo.xcprivacy`(无追踪、UserDefaults/文件时间戳 API 理由已声明)。
- ✅ App 图标全尺寸(16–1024)。
- ✅ 帮助页/文案已按平台门控,iOS 不显示 macOS-only 收词功能。
- ✅ iOS Debug/Release、macOS Release 均编译通过;Kit 70 测试通过。

---

## 步骤 1 — Apple 门户准备(App Store Connect)

1. **协议/税务/银行**:登录 [App Store Connect](https://appstoreconnect.apple.com) → 「协议、税务和银行业务」→ 确认《付费 App 协议》已生效、税务表和银行账户已填(**收内购款的前提**)。
2. **(可选)Small Business Program**:若年营收 < 100 万美元,申请后抽成 30%→15%。地址:ASC →「协议」页顶部横幅 / [developer.apple.com/app-store/small-business-program](https://developer.apple.com/app-store/small-business-program/)。
3. **新建 App 记录**:ASC →「我的 App」→「+」→ 新建 App
   - 平台:iOS
   - 名称:`WordClip`(全球唯一,若被占用需换,如 `WordClip - 单词收集`)
   - 主要语言:简体中文(或英文,看主市场)
   - Bundle ID:选 `xyz.phpz.WordClip`(需先在 [Certificates, IDs & Profiles](https://developer.apple.com/account/resources/identifiers/list) 注册该 App ID;Xcode 自动签名通常已注册)
   - SKU:自定义,如 `wordclip-ios`

---

## 步骤 2 — 内购商品

ASC → App → 「App 内购买项目」→「+」

- 类型:**非消耗型**
- 参考名称:`WordClip Pro Lifetime`
- 产品 ID:`xyz.phpz.WordClip.pro.lifetime`
- 定价:选一个价格档(对齐 `.storekit` 的 28 元档或你重新定的)
- 本地化(至少中/英各一):
  - zh:显示名「WordClip Pro（终身买断）」/ 描述「终身解锁 OCR 收词、iCloud 同步与导入/导出功能」
  - en:显示名「WordClip Pro (Lifetime)」/ 描述「Unlock OCR capture, iCloud sync, and import/export forever」
- 审核信息:上传一张 Paywall 截图 + 备注「一次性购买,永久解锁 Pro,无订阅」。
- **首次提交**:内购需与 App 版本**一起提交审核**(在版本页面的「App 内购买项目」区勾选加入本次提交)。

> 注意:iOS 端 Pro 权益中「iCloud 同步」当前是预留 UI(未实装)。**上架文案不要承诺 iCloud 同步已可用**,否则功能与描述不符会被拒。见下方描述草稿——已只列 OCR 与导入/导出。

---

## 步骤 3 — App 元数据(可直接复制)

**副标题(30 字内):**
```
选词收集 · 离线查词 · 间隔重复
```

**描述:**
```
WordClip 是一款专注「收集 → 查词 → 复习」的单词学习工具。

■ 随手收集
手动输入或从剪贴板粘贴,快速把遇到的生词收进生词本。

■ 离线查词
内置约 5 万词的 ECDICT 词库(音标 + 中英释义),完全离线;
支持词形还原(brought → bring 自动归一)。

■ 免费懒人包
分级包(初学者 / 高考 / CET-4/6 / 考研 / 托福 / 雅思 / GRE)与
场景包(日常 / 旅游 / 技术 / 商务),全部免费离线,一键导入即可学。

■ 科学复习
基于 SM-2 间隔重复算法,认识的词间隔越拉越长,不认识的词及时重现;
可按懒人包分组只学某一类,或混学全部。每日复习提醒。

■ 数据自主
学习进度本地存储,可导出 JSON 备份。

WordClip Pro(一次性买断,终身解锁):
· OCR 收词 — 框选屏幕/图片识别单词收录
· 词库导入 — 导入自有词库备份

收集与基础查词永久免费。
```

**关键词(100 字符内,逗号分隔):**
```
单词,背单词,生词本,词典,英语,查词,词汇,间隔重复,复习,考研,四六级,雅思,托福,GRE,离线词典
```

**支持 URL / 隐私政策 URL:**
- 需把 `docs/PRIVACY.md`、`docs/TERMS.md` 发布到公开地址(GitHub Pages / 项目主页),填入 ASC。
- 先完成 `docs/PRIVACY.md` 的上架前待办:替换真实联系邮箱、发布公开 URL。

**版权:** `© 2026 <你的名字/主体>`

---

## 步骤 4 — 隐私标签(App 隐私)

ASC → App → 「App 隐私」:

- 数据收集:**不收集数据**(No data collected)——与 `PrivacyInfo.xcprivacy` 一致。学习数据仅存本地。
- 追踪:否。
- 填入隐私政策 URL(同上)。

---

## 步骤 5 — 年龄分级

ASC → 版本 → 「年龄分级」问卷,全部选「无/None」→ 预期分级 **4+**。

---

## 步骤 6 — 截图

至少提供以下尺寸各一组(建议 3–5 张:生词本 / 查词 / 懒人包 / 复习卡 / 统计):

| 设备 | 尺寸(竖屏,像素) | 取图模拟器 |
|---|---|---|
| iPhone 6.9" | 1320 × 2868 | iPhone 17 Pro Max |
| iPad 13" | 2064 × 2752 | iPad Pro 13" (M4) |

> 当前 App Store Connect 只强制要求 6.9" iPhone + 13" iPad 各一组,其余尺寸自动缩放。
> 取图:模拟器运行 Release 构建 → `⌘S` 存桌面,或 `xcrun simctl io booted screenshot shot.png`。
> 建议先在 DEBUG 里打开「模拟 Pro」灌一些示例词再截,画面更丰满。

---

## 步骤 7 — Archive 上传

1. Xcode 打开 `WordClip.xcodeproj`(先 `xcodegen generate` 确保最新)。
2. 顶部目标选 **WordClip-iOS**,设备选 **Any iOS Device (arm64)**(不能是模拟器)。
3. 确认 scheme 的 Archive 配置为 **Release**(project.yml 已设)。
4. Product → **Archive**。
5. Organizer 窗口 → 选中归档 → **Distribute App** → App Store Connect → Upload。
6. 等 ASC 处理完构建(几分钟到半小时,邮件通知)。

---

## 步骤 8 —(建议)TestFlight 自测

- ASC → TestFlight → 选刚上传的 build → 邀自己为内部测试员 → 装到真机跑一遍:
  - 收词(手动/粘贴)、查词、懒人包导入、复习翻卡、导出。
  - **内购**:TestFlight 走沙盒账号,验证购买 → 解锁 OCR / 导入,及「恢复购买」。
  - 检查无 macOS-only 文案泄漏。

---

## 步骤 9 — 提交审核

1. ASC → App → 「1.0.0 版本」→ 填全元数据 + 截图 + 选 build + 勾选内购一起提交。
2. 「App 审核信息」:留联系方式;演示账号一般不需要(无登录)。
   - 备注建议:「本 App 无账号系统,数据仅本地存储。Pro 为一次性内购,解锁 OCR 收词与词库导入。」
3. 版本发布方式:手动 / 自动,选你要的。
4. 「提交以供审核」。

---

## 待办卡点(需你先补齐)

- [ ] 隐私政策 / 服务条款发布到公开 URL(先填 `docs/PRIVACY.md` 里的联系邮箱)。
- [ ] 决定线上定价档(¥28 或其他),与内购配置对齐。
- [ ] 确认 App 名称「WordClip」在 App Store 可用。
- [ ] 截图(6.9" iPhone + 13" iPad)。
- [x] App 图标 1024 无 alpha 通道 —— 已确认(`sips`:hasAlpha no,1024×1024)。

## 非目标(本次不做)

- iCloud 同步(未实装,文案已回避)。
- macOS 上架(走网站分发,见 `docs/PLAN.md`「分发路线」)。
- 订阅制(只做一次性买断)。
