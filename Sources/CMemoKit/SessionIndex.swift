import Foundation
import Combine

public final class SessionIndex: ObservableObject {
    private let store: SessionStore

    @Published public private(set) var summaries: [SessionSummary] = []

    public init(store: SessionStore) {
        self.store = store
    }

    public func reload() {
        summaries = (try? store.scan()) ?? []
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

    public func agentNames() -> [String] {
        Array(Set(summaries.map(\.agent))).sorted()
    }

    public struct DirectoryNode: Identifiable, Equatable {
        public let id: String
        public let name: String
        public let path: String
        public let children: [DirectoryNode]
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
}
