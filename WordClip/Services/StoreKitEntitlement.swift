import Foundation
import Combine
import StoreKit
import WordClipKit

/// StoreKit 2 实现的权益提供者：一次性买断（Non-Consumable）。
///
/// 与 `MockEntitlement` 实现同一 `EntitlementProvider` 协议，UI 不变即可切换。
/// 开发期用 `.storekit` Configuration File 即可跑通完整购买/恢复流程，无需付费账号；
/// 账号就绪后，把 `WordClipApp` 里的 `MockEntitlement` 换成本类即可。
@MainActor
public final class StoreKitEntitlement: EntitlementProvider, ObservableObject {

    /// 终身买断商品 ID（需与 `.storekit` 配置及 App Store Connect 保持一致）。
    public static let lifetimeProductID = "xyz.phpz.WordClip.pro.lifetime"

    @Published public private(set) var isPro: Bool = false

    public var isProPublisher: AnyPublisher<Bool, Never> {
        $isPro.eraseToAnyPublisher()
    }

    /// 缓存拉取到的 StoreKit 商品，供 purchase 复用。
    private var cachedProducts: [Product] = []
    private var updatesTask: Task<Void, Never>?

    public init() {
        // 监听交易更新（其他设备购买 / App 外恢复 / 家庭共享）。
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(verificationResult: update)
            }
        }
        // 启动即校验当前权益。
        Task { await refreshEntitlement() }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - EntitlementProvider

    public func products() async -> [PlanProduct] {
        do {
            let storeProducts = try await Product.products(for: [Self.lifetimeProductID])
            cachedProducts = storeProducts
            return storeProducts.map { product in
                PlanProduct(
                    product: .lifetime,
                    localizedTitle: product.displayName,
                    localizedPrice: product.displayPrice
                )
            }
        } catch {
            return []
        }
    }

    public func purchase(_ product: ProProduct) async throws {
        let storeProduct: Product
        if let cached = cachedProducts.first(where: { $0.id == Self.lifetimeProductID }) {
            storeProduct = cached
        } else {
            let fetched = try await Product.products(for: [Self.lifetimeProductID])
            cachedProducts = fetched
            guard let first = fetched.first else { throw StoreError.productUnavailable }
            storeProduct = first
        }

        let result = try await storeProduct.purchase()
        switch result {
        case .success(let verification):
            await handle(verificationResult: verification)
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    public func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlement()
    }

    // MARK: - Private

    /// 遍历当前有效交易，判断是否已购买 Pro。
    private func refreshEntitlement() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.lifetimeProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
    }

    /// 处理一笔交易校验结果：验证通过则解锁并 finish。
    private func handle(verificationResult: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verificationResult else { return }
        if transaction.productID == Self.lifetimeProductID,
           transaction.revocationDate == nil {
            isPro = true
        }
        await transaction.finish()
    }

    enum StoreError: Error { case productUnavailable }
}
