import Testing
import Foundation
@testable import cmemo

/// InstallCommand 纯函数测试：只测 snippet(for:) 与未知 agent 的 nil 返回，
/// 不起子进程（stdout/stderr 捕获不涉及进程边界）。
@Suite
final class InstallCommandTests {
    private static let fakeCmemoPath = "/usr/local/bin/cmemo"

    @Test
    func snippetForClaudeCodeContainsBothHooksAndCommands() throws {
        let snippet = try #require(
            InstallCommand.snippet(for: "claude-code", cmemoPath: Self.fakeCmemoPath))
        #expect(snippet.contains("UserPromptSubmit"))
        #expect(snippet.contains("Stop"))
        #expect(snippet.contains("cmemo record"))
        #expect(snippet.contains("cmemo claude-reply"))
    }

    @Test
    func snippetForClaudeCodeIsParsableJSONWithHooksStructure() throws {
        // 默认入口（内部解析当前可执行文件路径）同样必须产出合法 JSON
        let snippet = try #require(InstallCommand.snippet(for: "claude-code"))
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(snippet.utf8)) as? [String: Any])
        let hooks = try #require(object["hooks"] as? [String: Any])
        #expect(hooks["UserPromptSubmit"] != nil)
        #expect(hooks["Stop"] != nil)
    }

    @Test
    func snippetForUnknownAgentReturnsNil() {
        #expect(InstallCommand.snippet(for: "codex") == nil)
        #expect(InstallCommand.snippet(for: "") == nil)
    }

    @Test
    func runWithUnknownAgentReturnsOne() {
        #expect(InstallCommand.run(agent: "codex") == 1)
    }
}
