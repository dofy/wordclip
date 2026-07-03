#if os(macOS)
import SwiftUI

/// OCR 选词面板：把识别到的候选词以 chip 形式展示，多选后收录。
struct OCRWordPickerView: View {
    let words: [String]
    let onConfirm: ([String]) -> Void
    let onCancel: () -> Void

    @State private var selected: Set<String> = []

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "ocr.picker.title", defaultValue: "选择要收录的单词"))
                .font(.headline)

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(words, id: \.self) { word in
                        chip(word)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 260)

            HStack {
                Button(String(localized: "ocr.picker.cancel", defaultValue: "取消"),
                       role: .cancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    onConfirm(words.filter { selected.contains($0) })
                } label: {
                    Text(String(localized: "ocr.picker.confirm",
                                defaultValue: "收录 (\(selected.count))"))
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selected.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380, height: 380)   // 固定尺寸：ScrollView 无固有高度，避免 NSHostingView 尺寸塌缩
        .onExitCommand { onCancel() }
    }

    private func chip(_ word: String) -> some View {
        let isOn = selected.contains(word)
        return Button {
            if isOn { selected.remove(word) } else { selected.insert(word) }
        } label: {
            Text(word)
                .lineLimit(1)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn ? Color.accentColor : Color.secondary.opacity(0.12))
                )
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
#endif
