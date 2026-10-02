import Testing
import Foundation
@testable import CMemoKit

@Suite
struct ClaudeTranscriptTests {
    @Test
    func returnsTextOfLastAssistantLineThatHasText() {
        // 末条 assistant 行仅含 tool_use，应向前回溯到上一条含 text 的 assistant 行。
        let jsonl = """
        {"type":"user","message":{"role":"user","content":"hello"}}
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"draft answer"},{"type":"tool_use","id":"t1","name":"Bash","input":{}}]}}
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t2","name":"Read","input":{}}]}}
        """
        #expect(ClaudeTranscript.lastAssistantText(in: Data(jsonl.utf8)) == "draft answer")
    }

    @Test
    func returnsNilWhenNoAssistantTextBlocks() {
        let jsonl = """
        {"type":"user","message":{"role":"user","content":"hello"}}
        {"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{}}]}}
        """
        #expect(ClaudeTranscript.lastAssistantText(in: Data(jsonl.utf8)) == nil)
    }

    @Test
    func concatenatesMultipleTextBlocksInOrder() {
        let jsonl = """
        {"type":"assistant","message":{"content":[{"type":"text","text":"first "},{"type":"text","text":"second"}]}}
        """
        #expect(ClaudeTranscript.lastAssistantText(in: Data(jsonl.utf8)) == "first second")
    }

    @Test
    func skipsMalformedLinesAndEmptyInput() {
        let jsonl = """
        this is not json
        {"type":"assistant","message":{"content":[{"type":"text","text":"recovered"}]}}
        """
        #expect(ClaudeTranscript.lastAssistantText(in: Data(jsonl.utf8)) == "recovered")
        #expect(ClaudeTranscript.lastAssistantText(in: Data()) == nil)
    }
}
