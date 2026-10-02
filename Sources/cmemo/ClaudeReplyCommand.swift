import Foundation
import CMemoKit

enum ClaudeReplyCommand {
    /// 处理 Claude Code Stop hook 载荷（session_id / cwd / transcript_path），
    /// 提取 transcript 中最后的 assistant 文本并追加到会话存储，返回进程退出码。
    /// transcript 不可读或无 assistant 文本时静默成功：记录缺失优于 hook 报错。
    static func run(input: Data, store: SessionStore, now: @autoclosure () -> Date) -> Int32 {
        struct Payload: Decodable {
            var sessionID: String?
            var cwd: String?
            var transcriptPath: String?

            private enum CodingKeys: String, CodingKey {
                case sessionID = "session_id"
                case cwd
                case transcriptPath = "transcript_path"
            }
        }

        let payload = try? JSONDecoder().decode(Payload.self, from: input)
        guard let sessionID = payload?.sessionID, !sessionID.isEmpty,
              let cwd = payload?.cwd, !cwd.isEmpty,
              let transcriptPath = payload?.transcriptPath, !transcriptPath.isEmpty
        else {
            FileHandle.standardError.write(Data(
                "cmemo claude-reply: input must contain session_id, cwd and transcript_path\n".utf8))
            return 1
        }

        // transcript 不可读或无 assistant 文本：静默 exit 0。
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: transcriptPath)),
              let text = ClaudeTranscript.lastAssistantText(in: data) else {
            return 0
        }

        let event = SessionEvent(
            agent: "claude-code",
            sessionID: sessionID,
            cwd: cwd,
            role: .assistant,
            content: text,
            timestamp: now(),
            title: nil
        )
        do {
            _ = try store.append(event)
        } catch {
            FileHandle.standardError.write(Data("cmemo claude-reply: write failed: \(error)\n".utf8))
            return 1
        }
        return 0
    }
}
