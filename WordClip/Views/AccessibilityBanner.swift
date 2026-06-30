#if os(macOS)
import SwiftUI

/// 辅助功能授权引导横幅。
/// 当 app 未获得辅助功能权限时显示在主窗口顶部，引导用户一键跳转系统设置授权。
struct AccessibilityBanner: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "accessibility.banner.title",
                            defaultValue: "需要辅助功能权限"))
                    .font(.callout.bold())
                Text(String(localized: "accessibility.banner.body",
                            defaultValue: "WordClip 需要辅助功能权限才能读取选中的文字，请在系统设置中授权。"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(String(localized: "accessibility.banner.open",
                          defaultValue: "打开系统设置")) {
                SelectionReader.openAccessibilitySettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button {
                appState.dismissAccessibilityPrompt()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.yellow.opacity(0.12))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
#endif
