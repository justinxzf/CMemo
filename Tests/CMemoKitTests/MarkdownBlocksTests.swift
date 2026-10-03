import Testing
import Foundation
@testable import CMemoKit

@Suite struct MarkdownBlocksTests {
    @Test func headingLevelsAndRequiredSpace() {
        #expect(MarkdownBlocks.parse("# 标题") == [.heading(level: 1, text: "标题")])
        #expect(MarkdownBlocks.parse("### 小节") == [.heading(level: 3, text: "小节")])
        #expect(MarkdownBlocks.parse("###### 六级") == [.heading(level: 6, text: "六级")])
        // 7 个 # 不是标题；# 后无空格也不是标题
        #expect(MarkdownBlocks.parse("####### 七个") == [.paragraph(text: "####### 七个")])
        #expect(MarkdownBlocks.parse("#无空格") == [.paragraph(text: "#无空格")])
    }

    @Test func unorderedListWithAllMarkers() {
        #expect(MarkdownBlocks.parse("- 甲\n- 乙") == [.unorderedList(items: ["甲", "乙"])])
        #expect(MarkdownBlocks.parse("* 星号") == [.unorderedList(items: ["星号"])])
        #expect(MarkdownBlocks.parse("+ 加号") == [.unorderedList(items: ["加号"])])
    }

    @Test func orderedListNormalizesNumbers() {
        #expect(MarkdownBlocks.parse("1. 甲\n2. 乙\n10. 丙") == [.orderedList(items: ["甲", "乙", "丙"])])
        #expect(MarkdownBlocks.parse("1) 圆括号") == [.orderedList(items: ["圆括号"])])
    }

    @Test func codeBlockIsVerbatimAndSwallowsSpecialLines() {
        let src = "```swift\nlet a = 1\n# 不是标题\n- 不是列表\n```"
        #expect(MarkdownBlocks.parse(src) == [.codeBlock(code: "let a = 1\n# 不是标题\n- 不是列表")])
    }

    @Test func unclosedCodeBlockRunsToEnd() {
        #expect(MarkdownBlocks.parse("```\nabc\ndef") == [.codeBlock(code: "abc\ndef")])
    }

    @Test func quoteJoinsConsecutiveLines() {
        #expect(MarkdownBlocks.parse("> 第一行\n> 第二行") == [.quote(text: "第一行\n第二行")])
        #expect(MarkdownBlocks.parse(">无空格") == [.quote(text: "无空格")])
    }

    @Test func blankLinesSplitParagraphs() {
        #expect(MarkdownBlocks.parse("第一段\n续行\n\n第二段") == [
            .paragraph(text: "第一段\n续行"), .paragraph(text: "第二段"),
        ])
    }

    @Test func inlineSyntaxIsLeftIntactForViewLayer() {
        #expect(MarkdownBlocks.parse("**加粗** 与 `代码`") == [.paragraph(text: "**加粗** 与 `代码`")])
    }

    @Test func mixedDocumentPreservesOrder() {
        let src = """
        ## 计划
        先做解析器，再做视图。
        - 第一步
        - 第二步
        ```bash
        swift test
        ```
        > 注意：零依赖
        """
        #expect(MarkdownBlocks.parse(src) == [
            .heading(level: 2, text: "计划"),
            .paragraph(text: "先做解析器，再做视图。"),
            .unorderedList(items: ["第一步", "第二步"]),
            .codeBlock(code: "swift test"),
            .quote(text: "注意：零依赖"),
        ])
    }

    @Test func listEndsWhenPlainLineAppears() {
        #expect(MarkdownBlocks.parse("- 甲\n普通行") == [
            .unorderedList(items: ["甲"]), .paragraph(text: "普通行"),
        ])
    }

    @Test func emptyAndBlankContentYieldNoBlocks() {
        #expect(MarkdownBlocks.parse("").isEmpty)
        #expect(MarkdownBlocks.parse("\n\n").isEmpty)
    }
}
