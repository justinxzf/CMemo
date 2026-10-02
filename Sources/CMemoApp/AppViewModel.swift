import Foundation
import Combine
import CMemoKit

final class AppViewModel: ObservableObject {
    @Published var selectedAgent: String?
    @Published var selectedDirectory: String?
    @Published var searchText = ""
    @Published var selectedSession: SessionSummary?
    @Published private(set) var detailEvents: [SessionEvent] = []

    private let index: SessionIndex

    init(index: SessionIndex = SessionIndex(
        store: SessionStore(baseDirectory: SessionStore.defaultBaseDirectory())
    )) {
        self.index = index
        refresh()
    }

    /// agent + 目录 + 文本（标题 contains 匹配）三层过滤的会话列表。
    var visibleSessions: [SessionSummary] {
        let matches = index.sessions(agent: selectedAgent, directoryPrefix: selectedDirectory)
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return matches }
        return matches.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    /// 首项「全部」代表不过滤 agent。
    var agentOptions: [String] {
        ["全部"] + index.agentNames()
    }

    var directoryTree: [SessionIndex.DirectoryNode] {
        index.directoryTree()
    }

    func refresh() {
        objectWillChange.send()
        index.reload()
    }

    func select(session: SessionSummary?) {
        selectedSession = session
        detailEvents = session.map { (try? index.store.loadMessages(of: $0)) ?? [] } ?? []
    }

    /// 选中「全部」时清除 agent 过滤。
    func selectAgent(_ option: String) {
        selectedAgent = option == "全部" ? nil : option
    }
}
