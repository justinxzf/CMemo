import Foundation

/// 单个 Markdown 块级元素；行内语法（加粗/斜体/行内代码/链接）不在此解析，
/// 保留原文交给视图层的 AttributedString 行内渲染。
public enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case unorderedList(items: [String])
    case orderedList(items: [String])
    case codeBlock(code: String)
    case quote(text: String)
}

/// 极简 GFM 子集的块级解析器：标题、有序/无序列表、围栏代码块、引用、段落。
/// 不解析表格；未覆盖的语法按普通段落文本展示。
public enum MarkdownBlocks {
    public static func parse(_ content: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        // 待定块：连续同类行累积，遇到异类行/空行/文档结束即落盘
        var pending: Pending = .none
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        func flush() {
            switch pending {
            case .none:
                break
            case .paragraph(let ls):
                let text = ls.joined(separator: "\n")
                if !text.isEmpty { blocks.append(.paragraph(text: text)) }
            case .unorderedList(let items):
                if !items.isEmpty { blocks.append(.unorderedList(items: items)) }
            case .orderedList(let items):
                if !items.isEmpty { blocks.append(.orderedList(items: items)) }
            case .quote(let ls):
                let text = ls.joined(separator: "\n")
                if !text.isEmpty { blocks.append(.quote(text: text)) }
            case .code(let ls):
                let code = ls.joined(separator: "\n")
                if !code.isEmpty { blocks.append(.codeBlock(code: code)) }
            }
            pending = .none
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 围栏代码块：开启后内容逐字收集，内部语法不参与解析
            if trimmed.hasPrefix("```") {
                if case .code(let buffer) = pending {
                    pending = .none
                    if !buffer.isEmpty { blocks.append(.codeBlock(code: buffer.joined(separator: "\n"))) }
                } else {
                    flush()
                    pending = .code([])
                }
                continue
            }
            if case .code(var buffer) = pending {
                buffer.append(line)
                pending = .code(buffer)
                continue
            }

            if let level = headingLevel(trimmed) {
                flush()
                blocks.append(.heading(level: level, text: headingText(trimmed, level: level)))
                continue
            }

            if let item = unorderedListItem(trimmed) {
                if case .unorderedList(var items) = pending {
                    items.append(item)
                    pending = .unorderedList(items)
                } else {
                    flush()
                    pending = .unorderedList([item])
                }
                continue
            }

            if let item = orderedListItem(trimmed) {
                if case .orderedList(var items) = pending {
                    items.append(item)
                    pending = .orderedList(items)
                } else {
                    flush()
                    pending = .orderedList([item])
                }
                continue
            }

            if let quoted = quoteLine(trimmed) {
                if case .quote(var ls) = pending {
                    ls.append(quoted)
                    pending = .quote(ls)
                } else {
                    flush()
                    pending = .quote([quoted])
                }
                continue
            }

            if trimmed.isEmpty {
                flush()
                continue
            }

            if case .paragraph(var ls) = pending {
                ls.append(line)
                pending = .paragraph(ls)
            } else {
                flush()
                pending = .paragraph([line])
            }
        }
        flush()
        return blocks
    }

    private enum Pending {
        case none
        case paragraph([String])
        case unorderedList([String])
        case orderedList([String])
        case quote([String])
        case code([String])
    }

    /// `#{1,6} ` 前缀返回标题级别；超过 6 个或 # 后无空格不算标题
    private static func headingLevel(_ trimmed: String) -> Int? {
        var level = 0
        for ch in trimmed {
            guard ch == "#" else { break }
            level += 1
        }
        guard (1...6).contains(level),
              trimmed.count > level,
              trimmed[trimmed.index(trimmed.startIndex, offsetBy: level)] == " " else { return nil }
        return level
    }

    private static func headingText(_ trimmed: String, level: Int) -> String {
        String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
    }

    /// `- ` / `* ` / `+ ` 开头取条目文本
    private static func unorderedListItem(_ trimmed: String) -> String? {
        guard let first = trimmed.first, ["-", "*", "+"].contains(first),
              trimmed.count > 1,
              trimmed[trimmed.index(after: trimmed.startIndex)] == " " else { return nil }
        return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
    }

    /// `1. ` / `1) ` 开头取条目文本（序号归一化，不保留原始数字）
    private static func orderedListItem(_ trimmed: String) -> String? {
        for separator in [".", ")"] as [Character] {
            guard let sep = trimmed.firstIndex(of: separator), sep != trimmed.startIndex else { continue }
            let numberPart = trimmed[..<sep]
            guard !numberPart.isEmpty, numberPart.allSatisfy({ $0.isNumber }),
                  trimmed.count > numberPart.count + 1,
                  trimmed[trimmed.index(after: sep)] == " " else { continue }
            return String(trimmed[trimmed.index(sep, offsetBy: 2)...]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// `> ` 或 `>` 开头取引用文本
    private static func quoteLine(_ trimmed: String) -> String? {
        guard let first = trimmed.first, first == ">" else { return nil }
        guard trimmed.count > 1 else { return "" }
        let rest = trimmed.dropFirst()
        return rest.hasPrefix(" ") ? String(rest.dropFirst()) : String(rest)
    }
}
