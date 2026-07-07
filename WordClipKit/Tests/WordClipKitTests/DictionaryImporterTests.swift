import Testing
@testable import WordClipKit

@Suite("DictionaryImporter.parseCSV")
struct DictionaryImporterParseCSVTests {

    typealias Row = DictionaryImporter.CSVRow

    @Test("逗号分隔:两列(无音标)")
    func commaTwoColumns() {
        let rows = DictionaryImporter.parseCSV("apple,苹果")
        #expect(rows == [Row(word: "apple", definition: "苹果", phonetic: nil)])
    }

    @Test("逗号分隔:三列(含音标)")
    func commaThreeColumns() {
        let rows = DictionaryImporter.parseCSV("ephemeral,adj. 短暂的,ɪˈfem(ə)rəl")
        #expect(rows == [Row(word: "ephemeral", definition: "adj. 短暂的", phonetic: "ɪˈfem(ə)rəl")])
    }

    @Test("制表符分隔(TSV)")
    func tabSeparated() {
        let rows = DictionaryImporter.parseCSV("apple\t苹果\tˈæpl")
        #expect(rows == [Row(word: "apple", definition: "苹果", phonetic: "ˈæpl")])
    }

    @Test("双引号包裹 + 含逗号的释义")
    func quotedCommaInDefinition() {
        let rows = DictionaryImporter.parseCSV("run,\"v. 跑, 奔跑\"")
        #expect(rows == [Row(word: "run", definition: "v. 跑, 奔跑", phonetic: nil)])
    }

    @Test("双引号 \"\" 转义")
    func escapedQuotes() {
        let rows = DictionaryImporter.parseCSV("quote,\"她说\"\"你好\"\"\"")
        #expect(rows == [Row(word: "quote", definition: "她说\"你好\"", phonetic: nil)])
    }

    @Test("首行表头跳过:word / headword / 单词")
    func skipsHeader() {
        #expect(DictionaryImporter.parseCSV("word,definition\napple,苹果")
                == [Row(word: "apple", definition: "苹果", phonetic: nil)])
        #expect(DictionaryImporter.parseCSV("headword,def\napple,苹果")
                == [Row(word: "apple", definition: "苹果", phonetic: nil)])
        #expect(DictionaryImporter.parseCSV("单词,释义\napple,苹果")
                == [Row(word: "apple", definition: "苹果", phonetic: nil)])
    }

    @Test("空行跳过")
    func skipsEmptyLines() {
        let rows = DictionaryImporter.parseCSV("apple,苹果\n\n\nbanana,香蕉")
        #expect(rows == [
            Row(word: "apple", definition: "苹果", phonetic: nil),
            Row(word: "banana", definition: "香蕉", phonetic: nil),
        ])
    }

    @Test("字段不足(仅一列)跳过")
    func skipsSingleField() {
        let rows = DictionaryImporter.parseCSV("apple\nbanana,香蕉")
        #expect(rows == [Row(word: "banana", definition: "香蕉", phonetic: nil)])
    }

    @Test("音标列为空 → phonetic == nil")
    func emptyPhoneticIsNil() {
        let rows = DictionaryImporter.parseCSV("apple,苹果,")
        #expect(rows == [Row(word: "apple", definition: "苹果", phonetic: nil)])
    }
}
