import SwiftUI
import CMemoKit

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            DirectoryTreeView(viewModel: viewModel)
        } content: {
            SessionListView(viewModel: viewModel)
        } detail: {
            SessionDetailView(viewModel: viewModel)
        }
        .frame(minWidth: 1000, minHeight: 640)
    }
}

// MARK: - 占位子视图（真实交互在后续任务实现）

struct DirectoryTreeView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        List(flattenedPaths(viewModel.directoryTree), id: \.self) { path in
            Text(path)
        }
        .navigationTitle("目录")
    }

    private func flattenedPaths(_ nodes: [SessionIndex.DirectoryNode]) -> [String] {
        nodes.flatMap { [$0.path] + flattenedPaths($0.children) }
    }
}

struct SessionListView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        List(viewModel.visibleSessions, id: \.fileURL) { summary in
            Text(summary.title)
        }
        .navigationTitle("会话")
    }
}

struct SessionDetailView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.detailEvents.indices, id: \.self) { index in
                    let event = viewModel.detailEvents[index]
                    Text("[\(event.role.rawValue)] \(event.content)")
                }
            }
            .padding()
        }
        .navigationTitle("详情")
    }
}
