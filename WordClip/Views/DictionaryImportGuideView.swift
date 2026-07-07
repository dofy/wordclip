import SwiftUI

/// 「导入词典」功能说明页。仅从设置页词典分区 footer 的「了解如何导入」唤起。
/// 静态内容驱动,复用 HelpView 的原生分区排版(SwiftUI 不渲染 markdown 表格)。
struct DictionaryImportGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            titleBar
            Divider()
            scrollBody
        }
        .frame(width: 460, height: 600)
        #else
        NavigationStack {
            scrollBody
                .navigationTitle(String(localized: "dictguide.title", defaultValue: "如何导入词典"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "help.done", defaultValue: "完成")) { dismiss() }
                    }
                }
        }
        .presentationDetents([.large])
        #endif
    }

    #if os(macOS)
    private var titleBar: some View {
        HStack {
            Label(String(localized: "dictguide.title", defaultValue: "如何导入词典"),
                  systemImage: "character.book.closed")
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .focusable(false)
        }
        .padding(20)
    }
    #endif

    private var scrollBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // ① 这是什么
                section(String(localized: "dictguide.section.what", defaultValue: "这是什么")) {
                    item("character.book.closed",
                         String(localized: "dictguide.what.title", defaultValue: "扩充查词的释义来源"),
                         String(localized: "dictguide.what.body",
                                defaultValue: "导入的词典只在你查词时提供额外释义(如专业术语、其他语言),不会往生词本加词。想批量添加学习词条,请用「懒人包」。"))
                }
                // ② 什么时候需要
                section(String(localized: "dictguide.section.when", defaultValue: "什么时候需要")) {
                    item("sparkle.magnifyingglass",
                         String(localized: "dictguide.when.title", defaultValue: "多数人无需导入"),
                         String(localized: "dictguide.when.body",
                                defaultValue: "内置 ECDICT 5 万词已覆盖日常英语。适合这些情况:查专业领域词库(医学 / 法律 / 计算机)、需要英→其他语言释义、已有自制词表。"))
                }
                // ③ 支持的格式
                section(String(localized: "dictguide.section.format", defaultValue: "支持的格式")) {
                    VStack(alignment: .leading, spacing: 8) {
                        item("text.aligncenter",
                             String(localized: "dictguide.csv.title", defaultValue: "CSV 表格"),
                             String(localized: "dictguide.csv.body",
                                    defaultValue: "每行三列:单词、释义、音标(音标可省)。逗号或制表符分隔;首行表头可选;释义含逗号时用双引号包裹。"))
                        csvExample
                    }
                    item("cylinder.split.1x2",
                         String(localized: "dictguide.sqlite.title", defaultValue: "SQLite 词库"),
                         String(localized: "dictguide.sqlite.body",
                                defaultValue: "需含 entries 表,且有 word、definition 列(即 ECDICT 结构),导入时直接采用。"))
                }
                // ④ 怎么自己准备
                section(String(localized: "dictguide.section.prepare", defaultValue: "怎么自己准备")) {
                    item("tablecells",
                         String(localized: "dictguide.prepare.excel.title", defaultValue: "用表格软件做 CSV"),
                         String(localized: "dictguide.prepare.excel.body",
                                defaultValue: "在 Excel / Numbers / Google 表格里填三列,「另存为 / 导出」时选 CSV(UTF-8)即可。"))
                    item("chevron.left.forwardslash.chevron.right",
                         String(localized: "dictguide.prepare.sqlite.title", defaultValue: "进阶:自制 SQLite"),
                         String(localized: "dictguide.prepare.sqlite.body",
                                defaultValue: "可用开源词典数据自制。例如本 App 内置词库即来自 ECDICT(MIT 开源)。"))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        #if os(macOS)
        .onExitCommand { dismiss() }
        #endif
    }

    /// CSV 示例:等宽字体 + 浅底,让格式一目了然(英文示范不翻译)。
    private var csvExample: some View {
        Text("word,definition,phonetic\nephemeral,adj. 短暂的,ɪˈfem(ə)rəl")
            .font(.system(.callout, design: .monospaced))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
            .textSelection(.enabled)
    }

    // MARK: - 排版辅助

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func item(_ symbol: String, _ heading: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 22, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(heading).font(.body.weight(.medium))
                Text(body)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
