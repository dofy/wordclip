import Foundation
import WordClipKit

/// 读取 App bundle 内的词包清单(Resources/wordpacks/pack-*.json)。
enum WordPackCatalog {

    /// 解析全部词包,按文件名排序。解码失败的跳过。
    static func all() -> [WordPackDTO] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "wordpacks") else {
            return []
        }
        var packs: [WordPackDTO] = []
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let data = try? Data(contentsOf: url),
                  let pack = try? WordPackDTO.decode(from: data) else { continue }
            packs.append(pack)
        }
        return packs
    }
}
