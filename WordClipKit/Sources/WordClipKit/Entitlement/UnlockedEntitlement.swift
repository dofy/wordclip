import Combine
import Foundation

/// Pro 恒为解锁的权益实现，给不经 App Store 的直接分发构建用。
///
/// macOS 版走开发者直发（自签名或 Developer ID 的 DMG），拿不到 App Store 收据，
/// `StoreKitEntitlement` 在这种构建里永远判定未购买，OCR 取词和词典导入会被永久锁死
/// ——付费墙也点不出结果，因为没有可完成的交易。这个实现把 Pro 直接放开。
///
/// 为什么不复用 `MockEntitlement(overridePro: true)`：那个类把 `isPro` 持久化在
/// `UserDefaults` 的 `mock.isPro` 下，并且**已存值优先于** `overridePro`。同一台机器上
/// 跑过 DEBUG 构建就会留下一个 false，直发构建随后会被它锁住。这里不读任何存储。
///
/// 由 `WordClip/App/AppEntitlement.swift` 在 `WORDCLIP_DIRECT_DISTRIBUTION` 编译条件
/// 下选用。UI 层只看 `isPro`，所以全部付费墙入口都会走已解锁分支，不会留下点不动的
/// 购买按钮。
@MainActor
public final class UnlockedEntitlement: EntitlementProvider, ObservableObject {

    public let isPro = true

    public var isProPublisher: AnyPublisher<Bool, Never> {
        Just(true).eraseToAnyPublisher()
    }

    public init() {}

    /// 无事可做：这种构建里本来就没有未解锁状态。
    public func purchase(_ product: ProProduct) async throws {}

    /// 无事可做：没有需要恢复的交易。
    public func restore() async throws {}

    /// 不提供商品：付费墙在这种构建里不可达，列出价格只会误导。
    public func products() async -> [PlanProduct] { [] }
}
