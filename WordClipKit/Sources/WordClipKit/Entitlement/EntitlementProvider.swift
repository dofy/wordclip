import Foundation
import Combine

// MARK: - ProProduct

/// 收费政策：一次性购买、终身买断，**不做订阅**。
/// 目前只有一个终身买断商品；保留 enum 以便未来扩展（如家庭版）。
public enum ProProduct: String, Sendable, CaseIterable {
    case lifetime  // 终身买断（Non-Consumable 内购）
}

// MARK: - PlanProduct

public struct PlanProduct: Sendable {
    public let product: ProProduct
    public let localizedTitle: String
    public let localizedPrice: String  // 格式化后的价格字符串，如 "¥198"

    public init(
        product: ProProduct,
        localizedTitle: String,
        localizedPrice: String
    ) {
        self.product = product
        self.localizedTitle = localizedTitle
        self.localizedPrice = localizedPrice
    }
}

// MARK: - EntitlementProvider

/// 权益协议。UI 层统一走 isPro，不直接碰 StoreKit。
/// 开发期用 MockEntitlement，账号就绪后换 StoreKitEntitlement，UI 不变。
@MainActor
public protocol EntitlementProvider: AnyObject {
    /// 当前是否已解锁 Pro（一次买断即永久 true）
    var isPro: Bool { get }

    /// 权益状态变化时发出通知（用于 UI 实时响应）
    var isProPublisher: AnyPublisher<Bool, Never> { get }

    /// 发起购买
    func purchase(_ product: ProProduct) async throws

    /// 恢复购买（换设备 / 重装）
    func restore() async throws

    /// 获取商品列表（含价格）
    func products() async -> [PlanProduct]
}

// MARK: - MockEntitlement

/// 开发期占位，通过 `overridePro` 开关模拟已购买/未购买状态。
@MainActor
public final class MockEntitlement: EntitlementProvider, ObservableObject {

    @Published public var isPro: Bool

    public var isProPublisher: AnyPublisher<Bool, Never> {
        $isPro.eraseToAnyPublisher()
    }

    /// true = 模拟「已购买 Pro」；false = 模拟「免费用户」
    public init(overridePro: Bool = false) {
        self.isPro = overridePro
    }

    public func purchase(_ product: ProProduct) async throws {
        // Mock：直接切换为 Pro
        isPro = true
    }

    public func restore() async throws {
        // Mock：无操作
    }

    public func products() async -> [PlanProduct] {
        [
            PlanProduct(product: .lifetime, localizedTitle: "终身买断", localizedPrice: "¥198"),
        ]
    }
}
