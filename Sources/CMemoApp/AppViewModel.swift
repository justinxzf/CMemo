import Foundation
import Combine
import CMemoKit

final class AppViewModel: ObservableObject {
    @Published var selectedAgent: String?
    @Published var selectedDirectory: String?
    @Published var selectedSession: SessionSummary?
    @Published private(set) var detailEvents: [SessionEvent] = []

    private let index: SessionIndex

    init(index: SessionIndex = SessionIndex(
        store: SessionStore(baseDirectory: SessionStore.defaultBaseDirectory())
    )) {
        self.index = index
        refresh()
    }

    var visibleSessions: [SessionSummary] {
        index.sessions(agent: selectedAgent, directoryPrefix: selectedDirectory)
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
