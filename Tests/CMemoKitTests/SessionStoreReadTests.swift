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
