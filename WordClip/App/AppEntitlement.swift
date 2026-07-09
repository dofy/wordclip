import WordClipKit

/// App 层统一的权益类型别名。
///
/// - DEBUG:用 `MockEntitlement`,配合 `.storekit` 配置或调试开关,无需真实交易即可验证 UI。
/// - Release:用 `StoreKitEntitlement`,走真实 StoreKit 2 购买/恢复。
///
/// 所有视图以 `@EnvironmentObject var entitlement: AppEntitlement` 注入,
/// 切换实现只需改此处,视图代码不变。两实现同为 `EntitlementProvider` + `ObservableObject`。
#if DEBUG
typealias AppEntitlement = MockEntitlement
#else
typealias AppEntitlement = StoreKitEntitlement
#endif
