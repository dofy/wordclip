import SwiftUI

/// 添加单词面板：手动输入 + 粘贴。
/// 跨平台（iOS/iPad/macOS 通用）。
struct AddWordView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var isWorking = false
    @State private var resultMessage: String?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(String(localized: "addword.title", defaultValue: "添加单词"))
                    .font(.title2.bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // 输入框 + 添加
            HStack(spacing: 10) {
                TextField(
                    String(localized: "addword.placeholder", defaultValue: "输入英文单词"),
                    text: $text
                )
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
                .onSubmit { submit() }

                Button {
                    submit()
                } label: {
                    if isWorking {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(String(localized: "addword.add", defaultValue: "添加"))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
            }

            // 粘贴按钮（系统粘贴，无隐私提示）
            PasteButton(payloadType: String.self) { strings in
                guard let pasted = strings.first else { return }
                Task { @MainActor in await add(pasted) }
            }
            .buttonBorderShape(.capsule)

            if let resultMessage {
                Text(resultMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        #if os(macOS)
        .frame(width: 380, height: 240)
        #else
        .frame(maxWidth: 480)
        .presentationDetents([.height(280)])
        #endif
        .onAppear { fieldFocused = true }
    }

    private func submit() {
        let word = text.trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty else { return }
        Task { @MainActor in await add(word) }
    }

    @MainActor
    private func add(_ word: String) async {
        isWorking = true
        let msg = await appState.collect(word: word)
        isWorking = false
        withAnimation { resultMessage = msg }
        text = ""
    }
}
