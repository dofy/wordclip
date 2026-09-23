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
                .navigationTitle(String(localized: "dictguide.title", defaultValue: "How to Import a Dictionary"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "help.done", defaultValue: "Done")) { dismiss() }
                    }
                }
        }
        .presentationDetents([.large])
        #endif
    }

    #if os(macOS)
    private var titleBar: some View {
        HStack {
            Label(String(localized: "dictguide.title", defaultValue: "How to Import a Dictionary"),
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
                section(String(localized: "dictguide.section.what", defaultValue: "What This Is")) {
                    item("character.book.closed",
                         String(localized: "dictguide.what.title", defaultValue: "Extra sources for lookups"),
                         String(localized: "dictguide.what.body",
                                defaultValue: "Imported dictionaries only add extra definitions when you look up a word (e.g. specialized terms, other languages). They do not add words to your word list — use Word Packs for that."))
                }
                // ② 什么时候需要
                section(String(localized: "dictguide.section.when", defaultValue: "When You Need It")) {
                    item("sparkle.magnifyingglass",
                         String(localized: "dictguide.when.title", defaultValue: "Most people don't need this"),
                         String(localized: "dictguide.when.body",
                                defaultValue: "The built-in ECDICT (50k words) already covers everyday English. Useful when you want a specialized dictionary (medical / legal / tech), definitions into another language, or you have your own word list."))
                }
                // ③ 支持的格式
                section(String(localized: "dictguide.section.format", defaultValue: "Supported Formats")) {
                    VStack(alignment: .leading, spacing: 8) {
                        item("text.aligncenter",
                             String(localized: "dictguide.csv.title", defaultValue: "CSV table"),
                             String(localized: "dictguide.csv.body",
                                    defaultValue: "Three columns per row: word, definition, phonetic (phonetic optional). Comma- or tab-separated; header row optional; wrap a definition in double quotes if it contains a comma."))
                        csvExample
                    }
                    item("cylinder.split.1x2",
                         String(localized: "dictguide.sqlite.title", defaultValue: "SQLite database"),
                         String(localized: "dictguide.sqlite.body",
                                defaultValue: "Must contain an `entries` table with `word` and `definition` columns (ECDICT structure); adopted directly on import."))
                }
                // ④ 怎么自己准备
                section(String(localized: "dictguide.section.prepare", defaultValue: "How to Prepare One")) {
                    item("tablecells",
                         String(localized: "dictguide.prepare.excel.title", defaultValue: "Make a CSV in a spreadsheet"),
                         String(localized: "dictguide.prepare.excel.body",
                                defaultValue: "Fill three columns in Excel / Numbers / Google Sheets, then Save As / Export as CSV (UTF-8)."))
                    item("chevron.left.forwardslash.chevron.right",
                         String(localized: "dictguide.prepare.sqlite.title", defaultValue: "Advanced: build a SQLite file"),
                         String(localized: "dictguide.prepare.sqlite.body",
                                defaultValue: "Build one from open dictionary data. For example, this app's built-in dictionary comes from ECDICT (MIT-licensed)."))
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
        Text(verbatim: "word,definition,phonetic\nephemeral,adj. 短暂的,ɪˈfem(ə)rəl")  // i18n-exempt: CSV 格式示范，故意不翻译
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
