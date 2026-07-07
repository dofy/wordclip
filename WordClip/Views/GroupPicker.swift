import SwiftUI
import SwiftData
import WordClipKit

/// 分组选择器:全部 + 各分组(手动收录、各词包)。
struct GroupPicker: View {
    @Binding var selection: UUID?          // nil = 全部
    @Query(sort: \WordGroup.sortOrder) private var groups: [WordGroup]

    var body: some View {
        Picker(String(localized: "study.group", defaultValue: "分组"), selection: $selection) {
            Text(String(localized: "study.group.all", defaultValue: "全部")).tag(UUID?.none)
            ForEach(groups) { g in
                Label(g.name, systemImage: g.iconSymbol ?? "square.stack").tag(UUID?.some(g.id))
            }
        }
        .pickerStyle(.menu)
        // 工具栏默认把 Label 折叠成 iconOnly,导致选中项只剩图标;强制显示标题+图标。
        .labelStyle(.titleAndIcon)
    }
}
