import Testing
import Foundation
@testable import CMemoKit

@Suite struct CollapsedDirectoryTreeTests {
    private func makeIndex(cwds: [String]) throws -> SessionIndex {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmemo-collapse-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = SessionStore(baseDirectory: dir)
        for (index, cwd) in cwds.enumerated() {
            try store.append(SessionEvent(
                agent: "agent-\(index)", sessionID: "s-\(index)", cwd: cwd,
                role: .user, content: "hi", timestamp: Date(timeIntervalSince1970: 100), title: nil
            ))
        }
        let index = SessionIndex(store: store)
        index.reload()
        return index
    }

    @Test func singleChildChainsCollapseIntoJoinedPath() throws {
        let index = try makeIndex(cwds: [
            "/Users/xiezhaofei/work/projects/cmemo/backend/services/parser/src",
            "/Users/xiezhaofei/work/projects/cmemo/frontend/app",
            "/Users/xiezhaofei/AI/CMemo",
        ])
        let tree = index.collapsedDirectoryTree()

        // 顶层 Users 链无会话 → 合并为 Users/xiezhaofei（xiezhaofei 处分叉，停止合并）
        #expect(tree.count == 1)
        let top = try #require(tree.first)
        #expect(top.name == "Users/xiezhaofei")
        #expect(top.path == "/Users/xiezhaofei")

        let mid = try #require(top.children.first { $0.name == "work/projects/cmemo" })
        #expect(mid.path == "/Users/xiezhaofei/work/projects/cmemo")
        // cmemo 处分叉，两个单子链各自折成一行
        #expect(mid.children.map(\.name) == ["backend/services/parser/src", "frontend/app"])
        #expect(mid.children.map(\.path) == [
            "/Users/xiezhaofei/work/projects/cmemo/backend/services/parser/src",
            "/Users/xiezhaofei/work/projects/cmemo/frontend/app",
        ])
        #expect(mid.children.allSatisfy { $0.children.isEmpty })

        // 另一分叉：AI 下单子链到叶子
        let ai = try #require(top.children.first { $0.name == "AI/CMemo" })
        #expect(ai.path == "/Users/xiezhaofei/AI/CMemo")
        #expect(ai.children.isEmpty)
    }

    @Test func nodeWithSessionStaysExpanded() throws {
        // a/b 自身有会话 → a/b 不与子节点合并；a 无会话仍折进 a/b
        let index = try makeIndex(cwds: ["/a/b", "/a/b/c"])
        let tree = index.collapsedDirectoryTree()

        #expect(tree.count == 1)
        let top = try #require(tree.first)
        #expect(top.name == "a/b")
        #expect(top.path == "/a/b")
        #expect(top.children.map(\.name) == ["c"])
        #expect(top.children.map(\.path) == ["/a/b/c"])
    }

    @Test func deepChainCollapsesToOneLeafRow() throws {
        let index = try makeIndex(cwds: ["/x/y/z/w/v"])
        let tree = index.collapsedDirectoryTree()
        #expect(tree.map(\.name) == ["x/y/z/w/v"])
        #expect(tree.map(\.path) == ["/x/y/z/w/v"])
        #expect(try #require(tree.first).children.isEmpty)
    }

    @Test func emptySummariesYieldEmptyTree() throws {
        let index = try makeIndex(cwds: [])
        #expect(index.collapsedDirectoryTree().isEmpty)
    }

    @Test func siblingsSortByName() throws {
        let index = try makeIndex(cwds: ["/r/b/z", "/r/a/z"])
        let tree = index.collapsedDirectoryTree()
        let top = try #require(tree.first)
        #expect(top.name == "r")
        #expect(top.children.map(\.name) == ["a/z", "b/z"])
    }
}
