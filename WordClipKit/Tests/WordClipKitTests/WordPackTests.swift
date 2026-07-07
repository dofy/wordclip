import Testing
import Foundation
@testable import WordClipKit

@Suite("WordGroup model")
struct WordGroupModelTests {

    @Test("WordGroup 初始化与常量")
    func initAndConstants() {
        let g = WordGroup(name: "旅游娱乐", kind: WordGroup.kindPack, packSlug: "travel", iconSymbol: "airplane", sortOrder: 3)
        #expect(g.name == "旅游娱乐")
        #expect(g.kind == "pack")
        #expect(g.packSlug == "travel")
        #expect(g.iconSymbol == "airplane")
        #expect(g.sortOrder == 3)
        #expect(WordGroup.kindManual == "manual")
        #expect(WordGroup.manualGroupName == "手动收录")
    }
}

@Suite("WordPackDTO decoding")
struct WordPackDTODecodingTests {

    @Test("从 JSON 解码词包")
    func decodePack() throws {
        let json = """
        {
          "slug": "travel", "name": "旅游娱乐", "icon": "airplane",
          "kind": "pack", "version": 1, "language": "en",
          "words": [
            {"headword": "itinerary", "lemma": "itinerary", "definition": "n. 行程", "definitionEn": "a route", "phonetic": "aɪ"},
            {"headword": "Visa", "lemma": "visa", "definition": "n. 签证"}
          ]
        }
        """.data(using: .utf8)!

        let pack = try WordPackDTO.decode(from: json)
        #expect(pack.slug == "travel")
        #expect(pack.name == "旅游娱乐")
        #expect(pack.icon == "airplane")
        #expect(pack.version == 1)
        #expect(pack.words.count == 2)
        #expect(pack.words[0].lemma == "itinerary")
        #expect(pack.words[1].definitionEn == nil)   // 可选字段缺省
        #expect(pack.words[1].phonetic == nil)
    }
}
