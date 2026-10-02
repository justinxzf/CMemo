import SwiftUI

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                FilterBarView(viewModel: viewModel)
            }
        }
    }
}
