import WordClipKit

/// App 层统一的权益类型别名。
///
/// - DEBUG:用 `MockEntitlement`,配合 `.storekit` 配置或调试开关,无需真实交易即可验证 UI。
/// - Release + `WORDCLIP_DIRECT_DISTRIBUTION`:用 `UnlockedEntitlement`,Pro 恒为解锁。
///   这是 `scripts/package-release.sh` 打 DMG 时用的配置——直发构建拿不到 App Store
///   收据,不放开的话 OCR 取词和词典导入会永久锁死,而付费墙也没有能完成的交易。
/// - Release:用 `StoreKitEntitlement`,走真实 StoreKit 2 购买/恢复(App Store 上架用)。
///
/// 所有视图以 `@EnvironmentObject var entitlement: AppEntitlement` 注入,
/// 切换实现只需改此处,视图代码不变。两实现同为 `EntitlementProvider` + `ObservableObject`。
#if DEBUG
typealias AppEntitlement = MockEntitlement
#elseif WORDCLIP_DIRECT_DISTRIBUTION
typealias AppEntitlement = UnlockedEntitlement
#else
typealias AppEntitlement = StoreKitEntitlement
#endif
