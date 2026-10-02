import Foundation

public enum ClaudeTranscript {
    /// 从 Claude Code transcript JSONL 提取最后的 assistant 回复文本。
    /// 从末尾向前找第一条含 `type=="text"` 块的 assistant 行（transcript 常以
    /// 纯 tool_use 行收尾），按顺序拼接其中所有 text 块；无 assistant 文本返回 nil。
    /// 解析失败的行直接跳过（transcript 可能混入非 JSON 行）。
    public static func lastAssistantText(in data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let decoder = JSONDecoder()
        for line in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            guard let entry = try? decoder.decode(Entry.self, from: Data(line.utf8)),
                  entry.type == "assistant"
            else { continue }
            let joined = (entry.message?.content ?? [])
                .filter { $0.type == "text" }
                .compactMap(\.text)
                .joined()
            if !joined.isEmpty {
                return joined
            }
        }
        return nil
    }

    /// 字段全部可选：宽松解码，缺字段或类型不符的行按坏行处理。
    private struct Entry: Decodable {
        struct Message: Decodable {
            struct Block: Decodable {
                var type: String?
                var text: String?
            }
            var content: [Block]?
        }
        var type: String?
        var message: Message?
    }
}
