import Foundation
import WordClipKit

// 分组名与词包名的显示层本地化。
//
// WordGroup.name 和 WordPackDTO.name 都是**存储值**:前者写进 SwiftData(并随 iCloud
// 同步),后者是离线 JSON 里的字段。改掉存储值会让老库里的组认不出来,所以这里一律
// 保持存储值不变,只在渲染时按稳定标识(kind / packSlug / slug)换成当前语言的文案。
//
// 未知 slug(将来用户自制词包)落回存储值,不会显示成空白或 key。

extension WordGroup {
    /// 界面上显示的分组名。
    var displayName: String {
        if kind == WordGroup.kindManual {
            return String(localized: "group.manual", defaultValue: "Manually Added")
        }
        if let slug = packSlug, let localized = WordPackNames.localizedName(slug: slug) {
            return localized
        }
        return name
    }
}

extension WordPackDTO {
    /// 界面上显示的词包名。
    var displayName: String {
        WordPackNames.localizedName(slug: slug) ?? name
    }
}

/// 内置词包的 slug → 本地化名。
///
/// `String(localized:)` 的 key 必须是 StaticString,不能拼接,所以这里用 switch 穷举
/// 12 个内置包。加新包时在 `WordClip/Resources/wordpacks/` 加 JSON 的同时补一条。
enum WordPackNames {
    static func localizedName(slug: String) -> String? {
        switch slug {
        case "beginner":
            return String(localized: "pack.name.beginner", defaultValue: "Beginner (Zhongkao)")
        case "gaokao":
            return String(localized: "pack.name.gaokao", defaultValue: "Gaokao")
        case "cet4":
            return String(localized: "pack.name.cet4", defaultValue: "CET-4")
        case "cet6":
            return String(localized: "pack.name.cet6", defaultValue: "CET-6")
        case "kaoyan":
            return String(localized: "pack.name.kaoyan", defaultValue: "Postgraduate Entrance Exam")
        case "toefl":
            return String(localized: "pack.name.toefl", defaultValue: "TOEFL")
        case "ielts":
            return String(localized: "pack.name.ielts", defaultValue: "IELTS")
        case "gre":
            return String(localized: "pack.name.gre", defaultValue: "GRE")
        case "daily":
            return String(localized: "pack.name.daily", defaultValue: "Daily Life")
        case "travel":
            return String(localized: "pack.name.travel", defaultValue: "Travel & Leisure")
        case "programming":
            return String(localized: "pack.name.programming", defaultValue: "Tech English")
        case "business":
            return String(localized: "pack.name.business", defaultValue: "Business")
        default:
            return nil
        }
    }
}
