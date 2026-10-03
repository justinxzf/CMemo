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
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(MarkdownBlocks.parse(event.content).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .textSelection(.enabled)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(fillColor))
        .foregroundColor(foregroundColor)
        .frame(maxWidth: 560, alignment: event.role == .user ? .trailing : .leading)
    }

    private var fillColor: Color {
        event.role == .user ? .accentColor : Color.secondary.opacity(0.15)
    }

    private var foregroundColor: Color {
        event.role == .user ? .white : .primary
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(Self.inline(text))
                .font(Self.headingFont(level))
        case .paragraph(let text):
            Text(Self.inline(text))
        case .unorderedList(let items):
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(AttributedString("•  ") + Self.inline(item))
                }
            }
        case .orderedList(let items):
            VStack(alignment: .leading, spacing: 3) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Text(AttributedString("\(index + 1). ") + Self.inline(item))
                }
            }
        case .codeBlock(let code):
            Text(code)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(event.role == .user ? 0.15 : 0.08),
                            in: RoundedRectangle(cornerRadius: 6))
        case .quote(let text):
            HStack(alignment: .top, spacing: 6) {
                Rectangle()
                    .fill(event.role == .user ? Color.white.opacity(0.6) : Color.secondary.opacity(0.6))
                    .frame(width: 3)
                Text(Self.inline(text)).foregroundStyle(quoteColor)
            }
        }
    }

    private var quoteColor: Color {
        event.role == .user ? Color.white.opacity(0.85) : Color.secondary
    }

    /// 行内 Markdown（加粗/斜体/行内代码/链接）；保留换行，解析失败回退纯文本。
    private static func inline(_ markdown: String) -> AttributedString {
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

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2.bold()
        case 2: return .title3.bold()
        case 3: return .headline
        default: return .subheadline.bold()
        }
    }
}
