import SwiftUI
import SwiftData
import WordClipKit

/// 词包浏览与导入:网格列出所有包,已导入显示「已添加」,未导入可勾选批量导入。
struct WordPackBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    /// 首启引导模式:显示「跳过」;长驻模式:显示「完成」。
    var isOnboarding: Bool = false
    var onDone: () -> Void = {}

    @State private var packs: [WordPackDTO] = []
    @State private var selected: Set<String> = []
    @State private var importedCounts: [String: Int] = [:]
    @State private var isImporting = false

    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isOnboarding
                 ? String(localized: "packs.welcome.title", defaultValue: "Pick a word pack for a quick start")
                 : String(localized: "packs.browse.title", defaultValue: "Word Packs"))
                .font(.title2).bold()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(packs, id: \.slug) { pack in
                        card(pack)
                    }
                }
            }

            HStack {
                Button(isOnboarding
                       ? String(localized: "packs.skip", defaultValue: "Skip")
                       : String(localized: "packs.close", defaultValue: "Close")) { onDone() }
                Spacer()
                Button {
                    importSelected()
                } label: {
                    Text(String(localized: "packs.import", defaultValue: "Import (\(selected.count))"))
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty || isImporting)
            }
        }
        .padding(20)
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 480)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .task { load() }
    }

    private func card(_ pack: WordPackDTO) -> some View {
        let imported = (importedCounts[pack.slug] ?? 0) > 0
        let isOn = selected.contains(pack.slug)
        return Button {
            guard !imported else { return }
            if isOn { selected.remove(pack.slug) } else { selected.insert(pack.slug) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: pack.icon ?? "square.stack")
                    .font(.title2).frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.displayName).font(.headline)
                    Text(String(localized: "packs.wordcount", defaultValue: "\(pack.words.count) words")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if imported {
                    Label(String(localized: "packs.added", defaultValue: "Added"), systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly).foregroundStyle(.green)
                } else if isOn {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(imported ? 0.06 : 0.12)))
            .opacity(imported ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .focusable(false)   // 去掉网格卡片的键盘焦点环(macOS 上无意义)
    }

    private func load() {
        packs = WordPackCatalog.all()
        let store = WordPackStore(modelContext: modelContext)
        var counts: [String: Int] = [:]
        for p in packs { counts[p.slug] = store.importedCount(slug: p.slug) }
        importedCounts = counts
    }

    private func importSelected() {
        isImporting = true
        let store = WordPackStore(modelContext: modelContext)
        for pack in packs where selected.contains(pack.slug) {
            store.import(pack)
        }
        selected.removeAll()
        load()
        isImporting = false
        if isOnboarding { onDone() }
    }
}
