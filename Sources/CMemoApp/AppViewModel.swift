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
    private var searchDebounceTask: Task<Void, Never>?

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

    /// agent + 目录 + 关键字三层过滤的会话列表；关键字对标题与消息内容全文匹配。
    var visibleSessions: [SessionSummary] {
        index.searchSessions(query: searchText, agent: selectedAgent, directoryPrefix: selectedDirectory)
    }

    /// 首项「全部」代表不过滤 agent。
    var agentOptions: [String] {
        ["全部"] + index.agentNames()
    }

    var directoryTree: [SessionIndex.DirectoryNode] {
        index.directoryTree()
    }

    /// 展示用折叠目录树：无会话的单子链合并为一行（如 A/B/C/D）。
    var collapsedDirectoryTree: [SessionIndex.CollapsedDirectoryNode] {
        index.collapsedDirectoryTree()
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

    /// 输入防抖 250ms 后才更新 searchText——全文检索需读会话文件，避免逐键全量扫描。
    func updateSearch(_ text: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            self?.searchText = text
        }
    }
}
