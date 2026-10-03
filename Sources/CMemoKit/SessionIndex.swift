import Foundation
import Combine

public final class SessionIndex: ObservableObject {
    public let store: SessionStore

    @Published public private(set) var summaries: [SessionSummary] = []

    public init(store: SessionStore) {
        self.store = store
    }

    public func reload() {
        // 扫描失败（目录被替换/暂时不可读）时保留上次索引，避免整个会话列表被清空。
        guard let scanned = try? store.scan() else { return }
        summaries = scanned
    }

    public func sessions(agent: String?, directoryPrefix: String?) -> [SessionSummary] {
        summaries.filter { summary in
            if let agent, summary.agent != agent { return false }
            if let directoryPrefix {
                let cwd = summary.cwd
                if cwd != directoryPrefix && !cwd.hasPrefix(directoryPrefix + "/") { return false }
            }
            return true
        }
    }

    /// 关键字全文检索：标题或任一消息内容命中（不区分大小写）即视为相关；
    /// 空白查询等价于普通过滤；读取失败的文件按无命中处理。
    public func searchSessions(query: String, agent: String?, directoryPrefix: String?) -> [SessionSummary] {
        let base = sessions(agent: agent, directoryPrefix: directoryPrefix)
        let keyword = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return base }
        return base.filter { summary in
            if summary.title.localizedCaseInsensitiveContains(keyword) { return true }
            guard let messages = try? store.loadMessages(of: summary) else { return false }
            return messages.contains { $0.content.localizedCaseInsensitiveContains(keyword) }
        }
    }

    public func agentNames() -> [String] {
        Array(Set(summaries.map(\.agent))).sorted()
    }

    public struct DirectoryNode: Identifiable, Equatable {
        public let id: String
        public let name: String
        public let path: String
        public let children: [DirectoryNode]
    }

    /// 目录树展示用的折叠节点：自身无会话且只有单子链的中间目录不展开，
    /// 合并为一行（如 A/B/C/D）。name 为合并后的分量拼接，path 为真实完整路径。
    public struct CollapsedDirectoryNode: Identifiable, Equatable, Sendable {
        public let id: String
        public let name: String
        public let path: String
        public let children: [CollapsedDirectoryNode]
    }

    public func directoryTree() -> [DirectoryNode] {
        // 按所有 cwd 的路径分量增量建树，仅纳入有会话的路径。
        final class Node {
            let name: String
            let path: String
            var children: [String: Node] = [:]

            init(name: String, path: String) {
                self.name = name
                self.path = path
            }
        }

        let root = Node(name: "", path: "")
        for cwd in Set(summaries.map(\.cwd)) where !cwd.isEmpty {
            var node = root
            var path = ""
            for component in cwd.split(separator: "/").map(String.init) {
                path += "/\(component)"
                if node.children[component] == nil {
                    node.children[component] = Node(name: component, path: path)
                }
                node = node.children[component]!
            }
        }

        func convert(_ node: Node) -> DirectoryNode {
            DirectoryNode(
                id: node.path,
                name: node.name,
                path: node.path,
                children: node.children.values.sorted { $0.name < $1.name }.map(convert)
            )
        }
        return root.children.values.sorted { $0.name < $1.name }.map(convert)
    }

    /// 展示用目录树：折叠「无会话且仅单子」的中间目录链。
    public func collapsedDirectoryTree() -> [CollapsedDirectoryNode] {
        let sessionPaths = Set(summaries.map(\.cwd))
        func collapse(_ node: DirectoryNode) -> CollapsedDirectoryNode {
            var names = [node.name]
            var path = node.path
            var current = node
            // 自身无会话且恰好一个子节点 → 继续下钻合并；有会话、多子或叶子即停。
            while !sessionPaths.contains(current.path), current.children.count == 1 {
                let child = current.children[0]
                names.append(child.name)
                path = child.path
                current = child
            }
            return CollapsedDirectoryNode(
                id: path,
                name: names.joined(separator: "/"),
                path: path,
                children: current.children.map(collapse)
            )
        }
        return directoryTree().map(collapse)
    }
}
