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
                            defaultValue: "Accessibility Permission Needed"))
                    .font(.callout.bold())
                Text(String(localized: "accessibility.banner.body",
                            defaultValue: "WordClip needs Accessibility permission to read selected text. Grant it in System Settings."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(String(localized: "accessibility.banner.open",
                          defaultValue: "Open System Settings")) {
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
        .frame(maxWidth: .infinity)
        // 两层：警示色贴着内容，底下再垫 .bar，否则横幅是半透明的，
        // 窗口内容会透上来和文字糊在一起。
        .background(.yellow.opacity(0.12))
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
#endif
