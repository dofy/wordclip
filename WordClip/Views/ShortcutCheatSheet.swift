import SwiftUI

/// 键盘快捷键速查表。⌘/ 唤出，macOS 菜单亦可打开。
struct ShortcutCheatSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(String(localized: "shortcuts.title", defaultValue: "Keyboard Shortcuts"),
                      systemImage: "keyboard")
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

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Self.groups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                            ForEach(group.items) { item in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.desc)
                                        .font(.body)
                                    Spacer(minLength: 16)
                                    KeyCaps(keys: item.keys)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        #if os(macOS)
        .frame(width: 420, height: 520)
        #else
        .presentationDetents([.medium, .large])
        #endif
    }

    // MARK: - 数据

    struct Group: Identifiable {
        let id = UUID()
        let title: String
        let items: [Item]
    }
    struct Item: Identifiable {
        let id = UUID()
        let desc: String
        /// 一组按键（多个表示“或”，各自渲染成键帽）。
        let keys: [String]
    }

    static var groups: [Group] {
        [
            Group(title: String(localized: "shortcuts.group.nav", defaultValue: "Navigation"), items: [
                Item(desc: String(localized: "sidebar.allwords", defaultValue: "Wordbook"), keys: ["⌘1"]),
                Item(desc: String(localized: "sidebar.review", defaultValue: "Review"), keys: ["⌘2"]),
                Item(desc: String(localized: "sidebar.stats", defaultValue: "Stats"), keys: ["⌘3"]),
                Item(desc: String(localized: "tab.settings", defaultValue: "Settings"), keys: ["⌘,"]),
            ]),
            Group(title: String(localized: "shortcuts.group.wordlist", defaultValue: "Word List"), items: [
                Item(desc: String(localized: "shortcuts.add", defaultValue: "Add word"), keys: ["⌘N"]),
                Item(desc: String(localized: "shortcuts.search", defaultValue: "Focus the search field"), keys: ["⌘K", "⌘F"]),
                Item(desc: String(localized: "shortcuts.nav.rows", defaultValue: "Move between words"), keys: ["↑", "↓"]),
                Item(desc: String(localized: "shortcuts.open", defaultValue: "Open detail"), keys: ["⏎"]),
                Item(desc: String(localized: "shortcuts.speak", defaultValue: "Speak"), keys: ["⌘L"]),
                Item(desc: String(localized: "shortcuts.favorite", defaultValue: "Favorite / unfavorite"), keys: ["⌘D"]),
                Item(desc: String(localized: "shortcuts.repair", defaultValue: "Repair definition"), keys: ["⌘R"]),
                Item(desc: String(localized: "shortcuts.delete", defaultValue: "Delete"), keys: ["⌘⌫"]),
            ]),
            Group(title: String(localized: "shortcuts.group.detail", defaultValue: "Word Detail"), items: [
                Item(desc: String(localized: "shortcuts.detail.nav", defaultValue: "Previous / next word"), keys: ["↑", "↓"]),
                Item(desc: String(localized: "shortcuts.speak", defaultValue: "Speak"), keys: ["⌘L"]),
                Item(desc: String(localized: "shortcuts.favorite", defaultValue: "Favorite / unfavorite"), keys: ["⌘D"]),
                Item(desc: String(localized: "shortcuts.repair", defaultValue: "Repair definition"), keys: ["⌘R"]),
            ]),
            Group(title: String(localized: "shortcuts.group.study", defaultValue: "Study"), items: [
                Item(desc: String(localized: "shortcuts.flip", defaultValue: "Flip to the definition"), keys: [String(localized: "shortcuts.key.space", defaultValue: "Space")]),
                Item(desc: String(localized: "shortcuts.grade.wrong", defaultValue: "Don’t know"), keys: ["←"]),
                Item(desc: String(localized: "shortcuts.grade.correct", defaultValue: "Know it"), keys: ["→"]),
            ]),
            Group(title: String(localized: "shortcuts.group.general", defaultValue: "General"), items: [
                Item(desc: String(localized: "shortcuts.self", defaultValue: "Show this cheat sheet"), keys: ["⌘/"]),
            ]),
        ]
    }
}

/// 一组键帽渲染（多个键之间用“或”分隔）。
private struct KeyCaps: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(keys.enumerated()), id: \.offset) { idx, key in
                if idx > 0 {
                    Text(String(localized: "shortcuts.or", defaultValue: "or"))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(key)
                    .font(.system(.callout, design: .rounded).weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 0.5)
                    )
            }
        }
    }
}
