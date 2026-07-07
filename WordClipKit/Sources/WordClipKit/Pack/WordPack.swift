import Foundation

/// 词包中的单个词。释义在构建时由 ECDICT 补全,导入时无需再查库。
public struct WordPackWordDTO: Codable, Equatable, Sendable {
    public let headword: String
    public let lemma: String
    public let definition: String?
    public let definitionEn: String?
    public let phonetic: String?

    public init(headword: String, lemma: String, definition: String? = nil,
                definitionEn: String? = nil, phonetic: String? = nil) {
        self.headword = headword
        self.lemma = lemma
        self.definition = definition
        self.definitionEn = definitionEn
        self.phonetic = phonetic
    }
}

/// 一个懒人词包(分级包或场景包)的离线 JSON 结构。
public struct WordPackDTO: Codable, Equatable, Sendable {
    public let slug: String
    public let name: String
    public let icon: String?
    public let kind: String
    public let version: Int
    public let language: String
    public let words: [WordPackWordDTO]

    public init(slug: String, name: String, icon: String? = nil, kind: String = "pack",
                version: Int = 1, language: String = "en", words: [WordPackWordDTO]) {
        self.slug = slug
        self.name = name
        self.icon = icon
        self.kind = kind
        self.version = version
        self.language = language
        self.words = words
    }

    public static func decode(from data: Data) throws -> WordPackDTO {
        try JSONDecoder().decode(WordPackDTO.self, from: data)
    }
}
