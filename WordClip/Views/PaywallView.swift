import SwiftUI
import WordClipKit

/// 付费墙：单档「终身买断」。展示 Pro 三大权益，一次性购买解锁。
///
/// 收费政策：一次性购买、终身制，不做订阅（见 docs/PLAN.md §5）。
struct PaywallView: View {
    @EnvironmentObject private var entitlement: MockEntitlement
    @Environment(\.dismiss) private var dismiss

    @State private var product: PlanProduct?
    @State private var purchasing = false
    @State private var errorMessage: String?
    @State private var showingError = false

    /// Pro 三大权益。
    private struct Benefit: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private var benefits: [Benefit] {
        [
            Benefit(
                symbol: "text.viewfinder",
                title: String(localized: "paywall.benefit.ocr.title", defaultValue: "OCR 收词"),
                detail: String(localized: "paywall.benefit.ocr.detail",
                               defaultValue: "框选屏幕任意区域，识别其中的单词并收录")
            ),
            Benefit(
                symbol: "arrow.triangle.2.circlepath.icloud",
                title: String(localized: "paywall.benefit.sync.title", defaultValue: "iCloud 同步"),
                detail: String(localized: "paywall.benefit.sync.detail",
                               defaultValue: "词典与单词进度跨设备自动同步")
            ),
            Benefit(
                symbol: "square.and.arrow.up.on.square",
                title: String(localized: "paywall.benefit.io.title", defaultValue: "导入 / 导出"),
                detail: String(localized: "paywall.benefit.io.detail",
                               defaultValue: "备份并在新设备恢复你的词库")
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    benefitList
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
            footer
        }
        .frame(minWidth: 380, minHeight: 520)
        .task { product = await entitlement.products().first }
        .alert(String(localized: "paywall.error.title", defaultValue: "购买失败"),
               isPresented: $showingError, presenting: errorMessage) { _ in
            Button(String(localized: "common.ok", defaultValue: "好"), role: .cancel) {}
        } message: { Text($0) }
    }

    // MARK: - 分区

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text(String(localized: "paywall.title", defaultValue: "WordClip Pro"))
                .font(.largeTitle.bold())
            Text(String(localized: "paywall.subtitle",
                        defaultValue: "一次购买，终身解锁全部进阶功能"))
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var benefitList: some View {
        VStack(spacing: 16) {
            ForEach(benefits) { benefit in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: benefit.symbol)
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(benefit.title).font(.headline)
                        Text(benefit.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Divider()
            Button(action: buy) {
                HStack {
                    if purchasing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(buyTitle).fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(purchasing)
            .padding(.horizontal, 28)

            Button(String(localized: "paywall.restore", defaultValue: "恢复购买")) {
                restore()
            }
            .font(.footnote)
            .disabled(purchasing)

            Text(String(localized: "paywall.legal",
                        defaultValue: "一次性购买，无自动续费。"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
        }
    }

    private var buyTitle: String {
        if let price = product?.localizedPrice {
            return String(localized: "paywall.buy.price",
                          defaultValue: "终身解锁 · \(price)")
        }
        return String(localized: "paywall.buy", defaultValue: "终身解锁")
    }

    // MARK: - 操作

    private func buy() {
        purchasing = true
        Task {
            defer { purchasing = false }
            do {
                try await entitlement.purchase(.lifetime)
                if entitlement.isPro { dismiss() }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func restore() {
        purchasing = true
        Task {
            defer { purchasing = false }
            do {
                try await entitlement.restore()
                if entitlement.isPro { dismiss() }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}
