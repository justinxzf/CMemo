import Testing
import Foundation
@testable import CMemoKit

@Suite struct FullTextSearchTests {
    private func makeIndex() throws -> (SessionIndex, SessionStore) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmemo-search-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = SessionStore(baseDirectory: dir)
        let index = SessionIndex(store: store)
        return (index, store)
    }

    private func append(_ store: SessionStore, agent: String, sid: String, cwd: String, content: String) throws {
        try store.append(SessionEvent(
            agent: agent, sessionID: sid, cwd: cwd,
            role: .user, content: content, timestamp: Date(timeIntervalSince1970: 100), title: nil
        ))
    }

    @Test func keywordMatchesTitleOrAnyMessageContent() throws {
        let (index, store) = try makeIndex()
        try append(store, agent: "claude-code", sid: "hit-title", cwd: "/w", content: "开场白")
        try append(store, agent: "claude-code", sid: "hit-content", cwd: "/w", content: "先聊别的\n后面提到 Qdrant 向量库")
        try append(store, agent: "claude-code", sid: "miss", cwd: "/w", content: "毫无相关")
        index.reload()

        let hits = index.searchSessions(query: "Qdrant", agent: nil, directoryPrefix: nil)
        #expect(hits.map(\.sessionID) == ["hit-content"])
    }

    @Test func firstMessageServesAsTitleHit() throws {
        let (index, store) = try makeIndex()
        try append(store, agent: "a", sid: "s1", cwd: "/w", content: "正文没有关键词")
        // 标题即首条消息：关键词出现在首条消息 → 标题命中
        try append(store, agent: "a", sid: "s2", cwd: "/w", content: "调研 Vector 数据库")
        index.reload()

        let hits = index.searchSessions(query: "Vector", agent: nil, directoryPrefix: nil)
        #expect(hits.map(\.sessionID) == ["s2"])
    }

    @Test func searchIsCaseInsensitiveAcrossAgents() throws {
        let (index, store) = try makeIndex()
        try append(store, agent: "cursor", sid: "upper", cwd: "/w", content: "use JSONL FORMAT")
        try append(store, agent: "trae", sid: "lower", cwd: "/w", content: "use jsonl format")
        index.reload()

        #expect(index.searchSessions(query: "jsonl", agent: nil, directoryPrefix: nil).count == 2)
        #expect(index.searchSessions(query: "JSONL", agent: nil, directoryPrefix: nil).count == 2)
    }

    @Test func blankQueryReturnsAllAfterOtherFilters() throws {
        let (index, store) = try makeIndex()
        try append(store, agent: "cursor", sid: "s1", cwd: "/a", content: "x")
        try append(store, agent: "trae", sid: "s2", cwd: "/b", content: "y")
        index.reload()

        #expect(index.searchSessions(query: "   ", agent: nil, directoryPrefix: nil).count == 2)
        #expect(index.searchSessions(query: "", agent: "cursor", directoryPrefix: nil).map(\.sessionID) == ["s1"])
        #expect(index.searchSessions(query: "", agent: nil, directoryPrefix: "/a").map(\.sessionID) == ["s1"])
    }

    @Test func keywordCombinesWithAgentAndDirectoryFilters() throws {
        let (index, store) = try makeIndex()
        try append(store, agent: "cursor", sid: "a", cwd: "/a", content: "提到防抖")
        try append(store, agent: "trae", sid: "b", cwd: "/b", content: "也提到防抖")
        try append(store, agent: "cursor", sid: "c", cwd: "/b", content: "提到防抖但目录不符")
        index.reload()

        let hits = index.searchSessions(query: "防抖", agent: "cursor", directoryPrefix: "/b")
        #expect(hits.map(\.sessionID) == ["c"])
    }

    @Test func corruptedFileIsSkippedNotFatal() throws {
        let (index, store) = try makeIndex()
        try append(store, agent: "a", sid: "good", cwd: "/w", content: "命中关键词")
        let bad = store.baseDirectory.appendingPathComponent("a-broken.jsonl")
        try Data("{{{{ not json".utf8).write(to: bad)
        index.reload()

        #expect(index.searchSessions(query: "关键词", agent: nil, directoryPrefix: nil).map(\.sessionID) == ["good"])
    }
}
