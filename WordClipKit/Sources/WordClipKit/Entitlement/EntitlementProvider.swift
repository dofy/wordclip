import Foundation
import Combine

// MARK: - SubscriptionPlan

public enum SubscriptionPlan: String, Sendable, CaseIterable {
    case monthly   // 月订阅
    case yearly    // 年订阅（主推）
    case lifetime  // 终身买断
}

// MARK: - PlanProduct

public struct PlanProduct: Sendable {
    public let plan: SubscriptionPlan
    public let localizedTitle: String
    public let localizedPrice: String  // 格式化后的价格字符串，如 "¥18/月"
    public let isPopular: Bool         // 是否主推（年订阅标注）

    public init(
        plan: SubscriptionPlan,
        localizedTitle: String,
        localizedPrice: String,
        isPopular: Bool = false
    ) {
        self.plan = plan
        self.localizedTitle = localizedTitle
        self.localizedPrice = localizedPrice
        self.isPopular = isPopular
    }
}

// MARK: - EntitlementProvider

/// 订阅权益协议。UI 层统一走 isPro，不直接碰 StoreKit。
/// 开发期用 MockEntitlement，账号就绪后换 StoreKitEntitlement，UI 不变。
@MainActor
public protocol EntitlementProvider: AnyObject {
    /// 当前是否已订阅 Pro
    var isPro: Bool { get }

    /// 权益状态变化时发出通知（用于 UI 实时响应）
    var isProPublisher: AnyPublisher<Bool, Never> { get }

    /// 发起购买
    func purchase(_ plan: SubscriptionPlan) async throws

    /// 恢复购买
    func restore() async throws

    /// 获取商品列表（含价格）
    func products() async -> [PlanProduct]
}

// MARK: - MockEntitlement

/// 开发期占位，通过 `overridePro` 开关模拟已订阅/未订阅状态。
@MainActor
public final class MockEntitlement: EntitlementProvider, ObservableObject {

    @Published public var isPro: Bool

    public var isProPublisher: AnyPublisher<Bool, Never> {
        $isPro.eraseToAnyPublisher()
    }

    /// true = 模拟「已订阅 Pro」；false = 模拟「免费用户」
    public init(overridePro: Bool = false) {
        self.isPro = overridePro
    }

    public func purchase(_ plan: SubscriptionPlan) async throws {
        // Mock：直接切换为 Pro
        isPro = true
    }

    public func restore() async throws {
        // Mock：无操作
    }

    public func products() async -> [PlanProduct] {
        [
            PlanProduct(plan: .monthly,  localizedTitle: "月度订阅",  localizedPrice: "¥18/月"),
            PlanProduct(plan: .yearly,   localizedTitle: "年度订阅",  localizedPrice: "¥98/年", isPopular: true),
            PlanProduct(plan: .lifetime, localizedTitle: "终身买断",  localizedPrice: "¥198"),
        ]
    }
}
