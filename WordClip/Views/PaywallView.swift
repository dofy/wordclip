import SwiftUI
import WordClipKit

/// 付费墙：单档「终身买断」。展示当前平台已提供的 Pro 权益，一次性购买解锁。
///
/// 收费政策：一次性购买、终身制，不做订阅（见 docs/PLAN.md §5）。
struct PaywallView: View {
    @EnvironmentObject private var entitlement: AppEntitlement
    @Environment(\.dismiss) private var dismiss

    @State private var product: PlanProduct?
    @State private var purchasing = false
    @State private var errorMessage: String?
    @State private var showingError = false

    /// 当前平台已提供的 Pro 权益。
    private struct Benefit: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private var benefits: [Benefit] {
        var items: [Benefit] = []
        #if os(macOS)
        items.append(Benefit(
            symbol: "text.viewfinder",
            title: String(localized: "paywall.benefit.ocr.title", defaultValue: "OCR Capture"),
            detail: String(localized: "paywall.benefit.ocr.detail",
                           defaultValue: "Select any region of the screen to recognize the words in it and save them")
        ))
        #endif
        items.append(Benefit(
            symbol: "square.and.arrow.up.on.square",
            title: String(localized: "paywall.benefit.io.title", defaultValue: "Import / Export"),
            detail: String(localized: "paywall.benefit.io.detail",
                           defaultValue: "Back up your vocabulary and restore it on a new device")
        ))
        return items
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
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 520)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .task { product = await entitlement.products().first }
        .alert(String(localized: "paywall.error.title", defaultValue: "Purchase Failed"),
               isPresented: $showingError, presenting: errorMessage) { _ in
            Button(String(localized: "common.ok", defaultValue: "OK"), role: .cancel) {}
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
                        defaultValue: "One purchase, every advanced feature unlocked for life"))
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

            Button(String(localized: "paywall.restore", defaultValue: "Restore Purchase")) {
                restore()
            }
            .font(.footnote)
            .disabled(purchasing)

            Text(String(localized: "paywall.legal",
                        defaultValue: "One-time purchase. No subscription, no auto-renewal."))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
        }
    }

    private var buyTitle: String {
        if let price = product?.localizedPrice {
            return String(localized: "paywall.buy.price",
                          defaultValue: "Unlock for life · \(price)")
        }
        return String(localized: "paywall.buy", defaultValue: "Unlock for life")
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
