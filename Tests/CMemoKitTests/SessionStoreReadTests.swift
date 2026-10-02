import Testing
import Foundation
@testable import CMemoKit

@Suite
final class SessionStoreReadTests {
    private var dir: URL
    private var store: SessionStore

    init() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmemo-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = SessionStore(baseDirectory: dir)
    }

    deinit {
        try? FileManager.default.removeItem(at: dir)
    }

    private func write(_ name: String, _ text: String) throws {
        try text.write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    @Test
    func scanReturnsSummariesSortedByLastActive() throws {
        try store.append(SessionEvent(agent: "cursor", sessionID: "s1", cwd: "/a",
                                      role: .user, content: "first", timestamp: Date(timeIntervalSince1970: 100), title: nil))
        try store.append(SessionEvent(agent: "claude-code", sessionID: "s2", cwd: "/b",
                                      role: .user, content: "later", timestamp: Date(timeIntervalSince1970: 200), title: "T"))
        let all = try store.scan()
        #expect(all.count == 2)
        #expect(all.first?.sessionID == "s2")
        #expect(all.first?.title == "T")
        #expect(all.last?.title == "first") // 无 title 时取首条 content
        #expect(all.first?.agent == "claude-code")
    }

    @Test
    func scanFlagsCorruptedFileButContinues() throws {
        try write("cursor-broken.jsonl",
                  "{\"type\":\"meta\",\"cwd\":\"/a\",\"created_at\":\"1970-01-01T00:00:00Z\"}\n{\"corrupt half line")
        let all = try store.scan()
        #expect(all.count == 1)
        #expect(all[0].isCorrupted)
        #expect(all[0].messageCount == 0)
    }

    @Test
    func scanToleratesFileTruncatedMidMultibyteCharacter() throws {
        // 崩溃时半行写入若截断在多字节字符中间，严格 UTF-8 解码整文件会抛错；
        // scan 应按文件容错：该文件以 isCorrupted 收录，其余文件仍被索引。
        try store.append(SessionEvent(agent: "claude-code", sessionID: "good", cwd: "/a",
                                      role: .user, content: "ok", timestamp: Date(timeIntervalSince1970: 1), title: nil))

        let metaLine = "{\"type\":\"meta\",\"cwd\":\"/t\",\"created_at\":\"1970-01-01T00:00:00Z\"}\n"
        // 半行写入：JSON 未闭合、末尾截在 CJK 多字节序列中间（0xE4 是三字节 UTF-8 的首字节）
        let eventLine = "{\"agent\":\"cursor\",\"session_id\":\"tr\",\"cwd\":\"/t\",\"role\":\"user\",\"content\":\"你好"
        var data = Data(metaLine.utf8)
        data.append(Data(eventLine.utf8))
        data.append(contentsOf: [0xE4])
        try data.write(to: dir.appendingPathComponent("cursor-tr.jsonl"))

        let all = try store.scan()
        #expect(all.count == 2)
        #expect(all.map(\.sessionID).contains("good"))
        let truncated = try #require(all.first { $0.sessionID == "tr" })
        #expect(truncated.isCorrupted)
    }

    @Test
    func loadMessagesSkipsCorruptLines() throws {
        try store.append(SessionEvent(agent: "cursor", sessionID: "s1", cwd: "/a",
                                      role: .user, content: "q", timestamp: Date(timeIntervalSince1970: 1), title: nil))
        let url = dir.appendingPathComponent("cursor-s1.jsonl")
        try "\(try String(contentsOf: url, encoding: .utf8))GARBAGE\n"
            .write(to: url, atomically: true, encoding: .utf8)
        let summary = try #require(try store.scan().first)
        let events = try store.loadMessages(of: summary)
        #expect(events.count == 1)
        #expect(events[0].content == "q")
    }
}
