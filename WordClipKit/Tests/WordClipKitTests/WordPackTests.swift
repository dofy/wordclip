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

@Suite("WordPackImporter dedup")
struct WordPackImporterTests {

    private func pack(_ lemmas: [String]) -> WordPackDTO {
        WordPackDTO(slug: "t", name: "T", words: lemmas.map {
            WordPackWordDTO(headword: $0, lemma: $0)
        })
    }

    @Test("过滤掉本组已存在的 lemma")
    func filtersExisting() {
        let p = pack(["apple", "banana", "cherry"])
        let result = WordPackImporter.newWords(in: p, existingLemmas: ["banana"])
        #expect(result.map(\.lemma) == ["apple", "cherry"])
    }

    @Test("pack 内部重复 lemma 只保留首个")
    func dedupWithinPack() {
        let p = pack(["apple", "apple", "banana"])
        let result = WordPackImporter.newWords(in: p, existingLemmas: [])
        #expect(result.map(\.lemma) == ["apple", "banana"])
    }

    @Test("全部已存在返回空")
    func allExisting() {
        let p = pack(["apple", "banana"])
        let result = WordPackImporter.newWords(in: p, existingLemmas: ["apple", "banana"])
        #expect(result.isEmpty)
    }

    @Test("保持原始顺序")
    func preservesOrder() {
        let p = pack(["zebra", "alpha", "mango"])
        let result = WordPackImporter.newWords(in: p, existingLemmas: [])
        #expect(result.map(\.lemma) == ["zebra", "alpha", "mango"])
    }

    @Test("existingLemmas 大小写不敏感,避免重复导入")
    func existingLemmasCaseInsensitive() {
        let p = pack(["apple", "banana"])
        // 调用方传入未归一的大写 lemma,也应被视为已存在。
        let result = WordPackImporter.newWords(in: p, existingLemmas: ["Apple", "BANANA"])
        #expect(result.isEmpty)
    }
}
