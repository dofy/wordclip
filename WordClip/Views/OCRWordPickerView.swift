#if os(macOS)
import SwiftUI

/// 选词面板状态：先 analyzing（OCR 进行中），完成后切到 ready(候选词)。
@MainActor
final class OCRPickerModel: ObservableObject {
    enum Phase {
        case analyzing
        case ready([String])
    }

    @Published var phase: Phase = .analyzing
    var onConfirm: ([String]) -> Void = { _ in }
    var onCancel: () -> Void = {}
}

/// OCR 选词面板：先以「分析中」loading 状态呈现，OCR 完成后原地切换成候选词 chip 供多选收录。
struct OCRWordPickerView: View {
    @ObservedObject var model: OCRPickerModel

    @State private var selected: Set<String> = []

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 8)]

    var body: some View {
        Group {
            switch model.phase {
            case .analyzing:
                analyzingView
            case .ready(let words):
                pickerView(words)
            }
        }
        .padding(20)
        .frame(width: 380, height: 380)   // 固定尺寸：ScrollView 无固有高度，避免 NSHostingView 尺寸塌缩
        .onExitCommand { model.onCancel() }
    }

    // 「分析中」：转圈动画 + 提示词，覆盖 OCR 这一耗时步骤的等待感。
    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(String(localized: "ocr.analyzing", defaultValue: "Analyzing words…"))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func pickerView(_ words: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "ocr.picker.title", defaultValue: "Pick the words to collect"))
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
                Button(String(localized: "ocr.picker.cancel", defaultValue: "Cancel"),
                       role: .cancel) { model.onCancel() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    model.onConfirm(words.filter { selected.contains($0) })
                } label: {
                    Text(String(localized: "ocr.picker.confirm",
                                defaultValue: "Collect (\(selected.count))"))
                        .frame(minWidth: 80)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selected.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
