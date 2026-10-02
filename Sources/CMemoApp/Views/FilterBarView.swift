import SwiftUI

/// 工具栏过滤条：agent 筛选 + 文本过滤框（对会话标题做 contains 匹配）。
struct FilterBarView: View {
    @ObservedObject var viewModel: AppViewModel

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

        TextField("按标题过滤…", text: $viewModel.searchText)
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 220)
    }
}
