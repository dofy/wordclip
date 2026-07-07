import SwiftUI

/// App 内使用帮助面板。macOS 从「帮助」菜单、iOS/macOS 从设置页唤出。
/// 静态内容驱动，与仓库 HELP.md 对齐但为原生排版（SwiftUI 不渲染 markdown 表格）。
struct HelpView: View {
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
                .navigationTitle(String(localized: "help.title", defaultValue: "使用帮助"))
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

    // MARK: - 标题栏（macOS）

    #if os(macOS)
    private var titleBar: some View {
        HStack {
            Label(String(localized: "help.title", defaultValue: "使用帮助"),
                  systemImage: "questionmark.circle")
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

    // MARK: - 内容

    private var scrollBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ForEach(Self.sections) { section in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(section.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        ForEach(section.items) { item in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: item.symbol)
                                    .font(.body)
                                    .foregroundStyle(.tint)
                                    .frame(width: 22, alignment: .center)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.heading)
                                        .font(.body.weight(.medium))
                                    Text(item.body)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        #if os(macOS)
        .onExitCommand { dismiss() }
        #endif
    }

    // MARK: - 数据模型

    struct Section: Identifiable {
        let id = UUID()
        let title: String
        let items: [Item]
    }
    struct Item: Identifiable {
        let id = UUID()
        let symbol: String
        let heading: String
        let body: String
    }

    static var sections: [Section] {
        [
            Section(title: String(localized: "help.section.concepts", defaultValue: "核心概念"), items: [
                Item(symbol: "books.vertical",
                     heading: String(localized: "help.concepts.wordlist.title", defaultValue: "生词本"),
                     body: String(localized: "help.concepts.wordlist.body",
                                  defaultValue: "你收录、要学习的单词，带熟悉度与复习进度。")),
                Item(symbol: "character.book.closed",
                     heading: String(localized: "help.concepts.dictionary.title", defaultValue: "词典"),
                     body: String(localized: "help.concepts.dictionary.body",
                                  defaultValue: "用于查询的参考词库，内置 ECDICT 5 万词，可导入更多。")),
            ]),
            Section(title: String(localized: "help.section.collect", defaultValue: "收词（macOS）"), items: [
                Item(symbol: "cursorarrow.click.2",
                     heading: String(localized: "help.collect.selection.title", defaultValue: "选中收词 · ⌥⌘C"),
                     body: String(localized: "help.collect.selection.body",
                                  defaultValue: "任意 App 中选中英文单词按快捷键，弹 HUD 提示、不改剪贴板。首次需在系统设置授权「辅助功能」。")),
                Item(symbol: "text.viewfinder",
                     heading: String(localized: "help.collect.ocr.title", defaultValue: "OCR 收词 · ⌥⌘O（Pro）"),
                     body: String(localized: "help.collect.ocr.body",
                                  defaultValue: "框选屏幕任意区域识别单词，适用于图片 / PDF / 不可选文本。首次需授权「屏幕录制」。")),
                Item(symbol: "link",
                     heading: String(localized: "help.collect.url.title", defaultValue: "URL Scheme"),
                     body: String(localized: "help.collect.url.body",
                                  defaultValue: "wordclip://collect?word=<单词>，可从快捷指令、脚本调用收词。")),
                Item(symbol: "menubar.arrow.up.rectangle",
                     heading: String(localized: "help.collect.menubar.title", defaultValue: "状态栏图标"),
                     body: String(localized: "help.collect.menubar.body",
                                  defaultValue: "快速启用/停用收词、查看今日概览、开始复习、打开主窗口或设置。")),
            ]),
            Section(title: String(localized: "help.section.add", defaultValue: "添加与查词"), items: [
                Item(symbol: "plus.circle",
                     heading: String(localized: "help.add.manual.title", defaultValue: "手动添加（iOS）"),
                     body: String(localized: "help.add.manual.body",
                                  defaultValue: "生词本右上角「+」，手动输入或从剪贴板粘贴。")),
                Item(symbol: "magnifyingglass",
                     heading: String(localized: "help.add.search.title", defaultValue: "搜索并收录 · ⌘F"),
                     body: String(localized: "help.add.search.body",
                                  defaultValue: "上方显示生词本匹配词，下方显示词典中未收录的词，点击可预览释义并一键收录。")),
            ]),
            Section(title: String(localized: "help.section.packs", defaultValue: "词包(懒人包)"), items: [
                Item(symbol: "square.stack.3d.up",
                     heading: String(localized: "help.packs.what.title", defaultValue: "预置词包"),
                     body: String(localized: "help.packs.what.body",
                                  defaultValue: "分级包(初学者/高考/CET-4/6/考研/托福/雅思/GRE)与场景包(日常生活/旅游娱乐/技术英语/商务职场),全部免费离线,一键导入即可学习。")),
                Item(symbol: "folder",
                     heading: String(localized: "help.packs.group.title", defaultValue: "分组隔离与过滤"),
                     body: String(localized: "help.packs.group.body",
                                  defaultValue: "导入的词与手动收录的词按分组隔离。复习页顶部或生词本工具栏的分组选择器,可只学某个包,或选「全部」混学。")),
                Item(symbol: "trash",
                     heading: String(localized: "help.packs.remove.title", defaultValue: "移除词包"),
                     body: String(localized: "help.packs.remove.body",
                                  defaultValue: "在生词本工具栏把分组过滤到某个词包,点「移除此词包」并确认,即可删掉该包的全部单词与复习进度,之后仍可重新导入。")),
            ]),
            Section(title: String(localized: "help.section.review", defaultValue: "复习原理"), items: [
                Item(symbol: "circle.fill",
                     heading: String(localized: "help.review.states.title", defaultValue: "三种状态"),
                     body: String(localized: "help.review.states.body",
                                  defaultValue: "新词（绿，还没复习过）· 待复习（橙，到了该复习的时间）· 记忆新鲜（无徽标，离下次复习还早）。")),
                Item(symbol: "arrow.up.right",
                     heading: String(localized: "help.review.sm2.title", defaultValue: "SM-2 间隔重复"),
                     body: String(localized: "help.review.sm2.body",
                                  defaultValue: "认识 → 间隔越拉越长（1天→6天→…），越熟越久才提醒；不认识 → 重置回明天重新巩固。一直标记「不认识」的词会停留在「新词」。")),
            ]),
            Section(title: String(localized: "help.section.data", defaultValue: "数据与 Pro"), items: [
                Item(symbol: "square.and.arrow.up",
                     heading: String(localized: "help.data.backup.title", defaultValue: "备份导入 / 导出"),
                     body: String(localized: "help.data.backup.body",
                                  defaultValue: "导出 JSON 备份（免费，含学习进度）；在新设备导入恢复（Pro），按单词智能合并、不覆盖进度。")),
                Item(symbol: "crown",
                     heading: String(localized: "help.data.pro.title", defaultValue: "WordClip Pro"),
                     body: String(localized: "help.data.pro.body",
                                  defaultValue: "一次性买断、终身解锁：OCR 收词、iCloud 同步、词库导入/导出。收集与基础查词永久免费。")),
            ]),
            Section(title: String(localized: "help.section.faq", defaultValue: "常见问题"), items: [
                Item(symbol: "questionmark.circle",
                     heading: String(localized: "help.faq.hotkey.title", defaultValue: "收词快捷键没反应？"),
                     body: String(localized: "help.faq.hotkey.body",
                                  defaultValue: "检查系统设置是否授权「辅助功能」，以及设置 → 收词 里「启用全局收词」是否打开。")),
                Item(symbol: "questionmark.circle",
                     heading: String(localized: "help.faq.nodef.title", defaultValue: "某个词「暂无释义」？"),
                     body: String(localized: "help.faq.nodef.body",
                                  defaultValue: "可能收录时词典未就绪。进入生词本会自动补全，也可选中该词按 ⌘R 手动修复。")),
                Item(symbol: "questionmark.circle",
                     heading: String(localized: "help.faq.import.title", defaultValue: "导入的词典没生效？"),
                     body: String(localized: "help.faq.import.body",
                                  defaultValue: "确认在 设置 → 词典 里该词典的开关是打开的。")),
            ]),
        ]
    }
}
