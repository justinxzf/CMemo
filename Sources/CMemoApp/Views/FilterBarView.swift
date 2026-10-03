import SwiftUI

/// 工具栏过滤条：agent 筛选 + 搜索框（标题/消息内容全文检索，输入防抖）。
struct FilterBarView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var query = ""

    var body: some View {
        Picker("Agent", selection: Binding(
            get: { viewModel.selectedAgent ?? "全部" },
            set: { viewModel.selectAgent($0) }
        )) {
            ForEach(viewModel.agentOptions, id: \.self) { option in
                Text(option).tag(option)
            }
        }
        .pickerStyle(.menu)
        .fixedSize()

        TextField("搜索标题或内容…", text: $query)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 220)
            .onChange(of: query) { newValue in
                viewModel.updateSearch(newValue)
            }
    }
}
