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
    private var watcher: DirectoryWatcher?

    init(index: SessionIndex = SessionIndex(
        store: SessionStore(baseDirectory: SessionStore.defaultBaseDirectory())
    )) {
        self.index = index
        refresh()
        // 可选属性默认初始化为 nil，此后才能在逃逸闭包里捕获 self。
        let watcher = DirectoryWatcher(path: index.store.baseDirectory) { [weak self] in
            // 监听回调在私有队列上触发，统一跳主线程再刷新（SwiftUI 要求）。
            DispatchQueue.main.async { self?.refresh() }
        }
        self.watcher = watcher
        watcher.start()
    }

    deinit {
        watcher?.stop()
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
