import SwiftUI

/// App 内使用帮助面板。macOS 从「帮助」菜单、iOS/macOS 从设置页唤出。
/// 静态内容驱动，与仓库 HELP.md / HELP.zh-Hans.md / HELP.zh-Hant.md 对齐但为原生排版
/// （SwiftUI 不渲染 markdown 表格）。三份 md 与这里的 `help.*` key 靠人工保持一致，
/// 构建期没有关联；改文案时两边都要动。
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
                .navigationTitle(String(localized: "help.title", defaultValue: "Help"))
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

    // MARK: - 标题栏（macOS）

    #if os(macOS)
    private var titleBar: some View {
        HStack {
            Label(String(localized: "help.title", defaultValue: "Help"),
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
        var result: [Section] = [
            Section(title: String(localized: "help.section.concepts", defaultValue: "Basics"), items: [
                Item(symbol: "books.vertical",
                     heading: String(localized: "help.concepts.wordlist.title", defaultValue: "Word List"),
                     body: String(localized: "help.concepts.wordlist.body",
                                  defaultValue: "The words you’ve saved to study, with familiarity and review progress.")),
                Item(symbol: "character.book.closed",
                     heading: String(localized: "help.concepts.dictionary.title", defaultValue: "Dictionary"),
                     body: String(localized: "help.concepts.dictionary.body",
                                  defaultValue: "The reference lexicon for lookups — 50k built-in ECDICT words, importable for more.")),
            ]),
        ]

        // 收词分区仅 macOS(选中收词/OCR/状态栏均为 macOS 能力,iOS 不显示以免误导)。
        #if os(macOS)
        result.append(
            Section(title: String(localized: "help.section.collect", defaultValue: "Capture (macOS)"), items: [
                Item(symbol: "cursorarrow.click.2",
                     heading: String(localized: "help.collect.selection.title", defaultValue: "Select to Capture · ⌥⌘C"),
                     body: String(localized: "help.collect.selection.body",
                                  defaultValue: "Select a word in any app and press the hotkey — a HUD confirms, the clipboard is untouched. Grant Accessibility on first use.")),
                Item(symbol: "text.viewfinder",
                     heading: String(localized: "help.collect.ocr.title", defaultValue: "OCR Capture · ⌥⌘O (Pro)"),
                     body: String(localized: "help.collect.ocr.body",
                                  defaultValue: "Drag to select any screen region and recognize its words — works on images, PDFs, non-selectable text. Grant Screen Recording on first use.")),
                Item(symbol: "menubar.arrow.up.rectangle",
                     heading: String(localized: "help.collect.menubar.title", defaultValue: "Menu Bar Icon"),
                     body: String(localized: "help.collect.menubar.body",
                                  defaultValue: "See today's overview, toggle selection capture, or open the main window. The icon dims when capture is off.")),
            ])
        )
        #endif

        result += [
            Section(title: String(localized: "help.section.add", defaultValue: "Add & Look Up"), items: [
                Item(symbol: "plus.circle",
                     heading: String(localized: "help.add.manual.title", defaultValue: "Add Manually (iOS)"),
                     body: String(localized: "help.add.manual.body",
                                  defaultValue: "Tap “+” in the word list to type or paste from the clipboard.")),
                Item(symbol: "magnifyingglass",
                     heading: String(localized: "help.add.search.title", defaultValue: "Search & Save · ⌘F"),
                     body: String(localized: "help.add.search.body",
                                  defaultValue: "Matches in your list show on top; dictionary words you haven’t saved show below — tap to preview and save.")),
                Item(symbol: "link",
                     heading: String(localized: "help.collect.url.title", defaultValue: "URL Scheme"),
                     body: String(localized: "help.collect.url.body",
                                  defaultValue: "wordclip://collect?word=<word> — collect via Shortcuts or scripts (macOS and iOS).")),
            ]),
            Section(title: String(localized: "help.section.packs", defaultValue: "Word Packs"), items: [
                Item(symbol: "square.stack.3d.up",
                     heading: String(localized: "help.packs.what.title", defaultValue: "Built-in word packs"),
                     body: String(localized: "help.packs.what.body",
                                  defaultValue: "Graded packs (Beginner / Gaokao / CET-4 & CET-6 / Postgraduate / TOEFL / IELTS / GRE) and topic packs (Daily Life / Travel & Leisure / Tech English / Business). All free, all offline — import one and start studying.")),
                Item(symbol: "folder",
                     heading: String(localized: "help.packs.group.title", defaultValue: "Group isolation and filtering"),
                     body: String(localized: "help.packs.group.body",
                                  defaultValue: "Imported words stay in their own group, separate from the words you save yourself. Use the group picker at the top of Review, or in the word list toolbar, to study a single pack — or choose “All” to mix them.")),
                Item(symbol: "trash",
                     heading: String(localized: "help.packs.remove.title", defaultValue: "Removing a word pack"),
                     body: String(localized: "help.packs.remove.body",
                                  defaultValue: "Filter the word list to one pack, tap “Remove This Pack” and confirm: that deletes all of the pack’s words along with their review progress. You can import it again at any time.")),
            ]),
            Section(title: String(localized: "help.section.review", defaultValue: "How Review Works"), items: [
                Item(symbol: "circle.fill",
                     heading: String(localized: "help.review.states.title", defaultValue: "Three States"),
                     body: String(localized: "help.review.states.body",
                                  defaultValue: "New (green, not yet marked known) · Due (orange, time to review) · Fresh (no badge, next review still far off).")),
                Item(symbol: "arrow.up.right",
                     heading: String(localized: "help.review.sm2.title", defaultValue: "SM-2 Spaced Repetition"),
                     body: String(localized: "help.review.sm2.body",
                                  defaultValue: "Know it → the interval keeps growing (1d→6d→…); Don’t → reset to tomorrow. A word you keep marking unknown stays “New”.")),
            ]),
            Section(title: String(localized: "help.section.data", defaultValue: "Data & Pro"), items: [
                Item(symbol: "square.and.arrow.up",
                     heading: String(localized: "help.data.backup.title", defaultValue: "Backup Import / Export"),
                     body: String(localized: "help.data.backup.body",
                                  defaultValue: "Export a JSON backup (free, includes progress); import to restore on a new device (Pro), merged per word without overwriting progress.")),
                Item(symbol: "crown",
                     heading: String(localized: "help.data.pro.title", defaultValue: "WordClip Pro"),
                     body: String(localized: "help.data.pro.body",
                                  defaultValue: "One-time purchase, lifetime unlock: OCR capture, iCloud sync, import/export. Collecting and basic lookup are always free.")),
            ]),
            Section(title: String(localized: "help.section.faq", defaultValue: "FAQ"), items: faqItems),
        ]
        return result
    }

    /// 常见问题条目。「快捷键没反应」仅 macOS(涉及辅助功能/选中收词开关)。
    private static var faqItems: [Item] {
        var items: [Item] = []
        #if os(macOS)
        items.append(
            Item(symbol: "questionmark.circle",
                 heading: String(localized: "help.faq.hotkey.title", defaultValue: "Capture hotkey does nothing?"),
                 body: String(localized: "help.faq.hotkey.body",
                              defaultValue: "Check that Accessibility is granted in System Settings, and that “Enable Selection Capture” is on under Settings → Selection Capture. (OCR capture is independent and unaffected by this switch.)"))
        )
        #endif
        items += [
            Item(symbol: "questionmark.circle",
                 heading: String(localized: "help.faq.nodef.title", defaultValue: "A word shows “No definition”?"),
                 body: String(localized: "help.faq.nodef.body",
                              defaultValue: "The dictionary may not have been ready when it was saved. It auto-fills in the word list, or press ⌘R to repair.")),
            Item(symbol: "questionmark.circle",
                 heading: String(localized: "help.faq.import.title", defaultValue: "Imported dictionary not working?"),
                 body: String(localized: "help.faq.import.body",
                              defaultValue: "Make sure the dictionary is toggled on under Settings → Dictionaries.")),
        ]
        return items
    }
}
