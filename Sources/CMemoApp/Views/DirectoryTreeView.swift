import SwiftUI
import CMemoKit

/// 目录树：OutlineGroup 渲染 directoryTree，点击选中目录联动过滤，再点取消。
struct DirectoryTreeView: View {
    @ObservedObject var viewModel: AppViewModel

    /// OutlineGroup 的 children 需为 Optional，叶子节点置 nil 以隐藏展开箭头。
    private struct OutlineNode: Identifiable {
        let id: String
        let name: String
        let path: String
        let children: [OutlineNode]?
    }

    var body: some View {
        List(selection: Binding(
            get: { viewModel.selectedDirectory },
            set: { newValue in
                if newValue != nil, newValue == viewModel.selectedDirectory {
                    viewModel.selectedDirectory = nil
                } else {
                    viewModel.selectedDirectory = newValue
                }
            }
        )) {
            OutlineGroup(outlineNodes(viewModel.directoryTree), children: \.children) { node in
                Text(node.name)
                    .tag(node.path)
            }
        }
        .navigationTitle("目录")
    }

    private func outlineNodes(_ nodes: [SessionIndex.DirectoryNode]) -> [OutlineNode] {
        nodes.map { node in
            OutlineNode(
                id: node.id,
                name: node.name,
                path: node.path,
                children: node.children.isEmpty ? nil : outlineNodes(node.children)
            )
        }
    }
}
