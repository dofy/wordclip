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
