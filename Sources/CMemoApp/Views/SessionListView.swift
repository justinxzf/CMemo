import SwiftUI
import CMemoKit

/// 会话列表：按 lastActiveAt 倒序，行 = 标题 + agent 标签 + 消息数 + 相对时间，选中联动详情。
struct SessionListView: View {
    @ObservedObject var viewModel: AppViewModel

    private static let relativeFormatter = RelativeDateTimeFormatter()

    var body: some View {
        List(selection: Binding(
            get: { viewModel.selectedSession?.fileURL },
            set: { url in
                guard let url else {
                    viewModel.select(session: nil)
                    return
                }
                viewModel.select(session: viewModel.visibleSessions.first { $0.fileURL == url })
            }
        )) {
            ForEach(sessionsSortedByLastActive, id: \.fileURL) { summary in
                SessionRow(summary: summary)
                    .tag(summary.fileURL)
            }
        }
        .navigationTitle("会话")
        // 过滤条固定在会话列表顶部，保证搜索框始终可见。
        .safeAreaInset(edge: .top, spacing: 0) {
            FilterBarView(viewModel: viewModel)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.bar)
        }
    }

    private var sessionsSortedByLastActive: [SessionSummary] {
        viewModel.visibleSessions.sorted { $0.lastActiveAt > $1.lastActiveAt }
    }
}

private struct SessionRow: View {
    let summary: SessionSummary

    private static let relativeFormatter = RelativeDateTimeFormatter()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.title.isEmpty ? summary.sessionID : summary.title)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 8) {
                Text(summary.agent)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.secondary.opacity(0.2)))
                Text("\(summary.messageCount) 条")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Self.relativeFormatter.localizedString(
                    for: summary.lastActiveAt,
                    relativeTo: Date()
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
