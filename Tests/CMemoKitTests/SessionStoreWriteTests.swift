import Testing
import Foundation
@testable import CMemoKit

@Suite
final class SessionStoreWriteTests {
    private var dir: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmemo-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: dir)
    }

    private func event(_ sid: String = "abc", content: String = "hi") -> SessionEvent {
        SessionEvent(agent: "claude-code", sessionID: sid, cwd: "/tmp/p",
                     role: .user, content: content, timestamp: Date(timeIntervalSince1970: 100), title: nil)
    }

    @Test
    func appendCreatesFileWithMetaThenMessageLines() throws {
        let store = SessionStore(baseDirectory: dir)
        let url = try store.append(event())
        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 2)
        #expect(lines[0].contains("\"type\""))
        #expect(lines[0].contains("\"created_at\""))
        #expect(lines[1].contains("\"content\""))
        #expect(url.lastPathComponent == "claude-code-abc.jsonl")
    }

    @Test
    func appendTwiceAppendsWithoutDuplicatingMeta() throws {
        let store = SessionStore(baseDirectory: dir)
        try store.append(event())
        try store.append(event(content: "second"))
        let lines = try String(contentsOf: dir.appendingPathComponent("claude-code-abc.jsonl"),
                               encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 3) // meta + 2 messages
    }

    @Test
    func sanitizedSessionID() {
        #expect(SessionStore.sanitizedSessionID("a/b c..d") == "a_b_c..d")
        #expect(SessionStore.sanitizedSessionID("ok-id_1.x") == "ok-id_1.x")
    }

    @Test
    func specialCharacterSessionIDStaysInOneFile() throws {
        let store = SessionStore(baseDirectory: dir)
        let url = try store.append(event("../../etc/passwd"))
        #expect(url.path.hasPrefix(dir.path)) // 未逃逸出存储目录
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test
    func largeContentRoundTrips() throws {
        let store = SessionStore(baseDirectory: dir)
        let big = String(repeating: "x", count: 1_000_000)
        let url = try store.append(event(content: big))
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(raw.contains(big))
    }

    @Test
    func specialCharacterAgentStaysInOneFile() throws {
        let store = SessionStore(baseDirectory: dir)
        let evil = SessionEvent(agent: "../evil", sessionID: "abc", cwd: "/tmp/p",
                                role: .user, content: "hi",
                                timestamp: Date(timeIntervalSince1970: 100), title: nil)
        let url = try store.append(evil)
        #expect(url.path.hasPrefix(dir.path)) // agent 含路径分隔符也不逃逸出存储目录
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
