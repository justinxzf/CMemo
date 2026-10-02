import Testing
import Foundation
@testable import CMemoKit

@Suite
final class SessionIndexTests {
    private var dir: URL
    private var store: SessionStore

    init() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmemo-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        store = SessionStore(baseDirectory: dir)
        try store.append(SessionEvent(agent: "cursor", sessionID: "1", cwd: "/Users/x/AI/CMemo",
                                      role: .user, content: "a", timestamp: Date(timeIntervalSince1970: 1), title: nil))
        try store.append(SessionEvent(agent: "cursor", sessionID: "2", cwd: "/Users/x/AI/CMemo",
                                      role: .user, content: "b", timestamp: Date(timeIntervalSince1970: 2), title: nil))
        try store.append(SessionEvent(agent: "claude-code", sessionID: "3", cwd: "/Users/x/Web",
                                      role: .user, content: "c", timestamp: Date(timeIntervalSince1970: 3), title: nil))
    }

    deinit {
        try? FileManager.default.removeItem(at: dir)
    }

    @Test
    func reloadKeepsPreviousIndexWhenScanFails() throws {
        let idx = SessionIndex(store: store)
        idx.reload()
        #expect(idx.summaries.count == 3)

        // 把 sessions 目录替换成普通文件，contentsOfDirectory 抛错模拟扫描失败
        try FileManager.default.removeItem(at: dir)
        try Data("not a directory".utf8).write(to: dir)

        idx.reload()
        #expect(idx.summaries.count == 3) // 扫描失败应保留上次索引而非清空
    }

    @Test
    func testFilterByAgent() {
        let idx = SessionIndex(store: store)
        idx.reload()
        #expect(idx.sessions(agent: "cursor", directoryPrefix: nil).count == 2)
        #expect(idx.sessions(agent: nil, directoryPrefix: nil).count == 3)
        #expect(idx.agentNames() == ["claude-code", "cursor"])
    }

    @Test
    func testFilterByDirectoryPrefixMatchesComponentBoundary() {
        let idx = SessionIndex(store: store)
        idx.reload()
        #expect(idx.sessions(agent: nil, directoryPrefix: "/Users/x/AI").count == 2)
        #expect(idx.sessions(agent: nil, directoryPrefix: "/Users/x/AI/CM").count == 0) // 非整段不匹配
    }

    @Test
    func testDirectoryTreeStructure() {
        let idx = SessionIndex(store: store)
        idx.reload()
        let tree = idx.directoryTree()
        #expect(tree.map(\.name) == ["Users"])
        let users = tree[0]
        // 注：brief 原文期望漏掉了 cwd "/Users/x/AI/CMemo" 的 "x" 分量，按规格
        // "按所有 cwd 的路径分量构建" 修正为 Users → x → {AI → CMemo, Web}。
        #expect(users.children.map(\.name) == ["x"])
        let x = users.children[0]
        #expect(x.path == "/Users/x")
        #expect(x.children.map(\.name) == ["AI", "Web"])
        #expect(x.children[0].path == "/Users/x/AI")
        #expect(x.children[0].children.map(\.name) == ["CMemo"])
        #expect(x.children[0].children[0].path == "/Users/x/AI/CMemo")
    }
}
