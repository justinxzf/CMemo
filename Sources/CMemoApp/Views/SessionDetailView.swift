import SwiftUI
import CMemoKit

/// 会话详情：user 气泡靠右蓝色、assistant 气泡靠左灰色，Markdown 渲染失败回退纯文本。
struct SessionDetailView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Group {
            if viewModel.selectedSession == nil {
                Text("选择一个会话查看详情")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.detailEvents.indices, id: \.self) { index in
                            EventBubble(event: viewModel.detailEvents[index])
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("详情")
    }
}

private struct EventBubble: View {
    let event: SessionEvent

    var body: some View {
        HStack(alignment: .bottom) {
            if event.role == .user { Spacer(minLength: 60) }
            bubble
            if event.role == .assistant { Spacer(minLength: 60) }
        }
    }

    private var bubble: some View {
        Text(Self.render(event.content))
            .textSelection(.enabled)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(fillColor))
            .foregroundColor(foregroundColor)
    }

    private var fillColor: Color {
        event.role == .user ? .accentColor : Color.secondary.opacity(0.15)
    }

    private var foregroundColor: Color {
        event.role == .user ? .white : .primary
    }

    /// Markdown 渲染；解析失败回退纯文本。保留换行以适配聊天气泡。
    private static func render(_ markdown: String) -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            return attributed
        }
        return AttributedString(markdown)
    }
}
