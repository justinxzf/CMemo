import Foundation

enum InstallCommand {
    static let supportedAgents = ["claude-code"]

    /// 生成指定 agent 可直接粘入 settings.json 的 hooks 配置片段；未知 agent 返回 nil。
    /// 纯函数：路径解析内嵌其中，测试只断言输出内容特征。
    static func snippet(for agent: String) -> String? {
        snippet(for: agent, cmemoPath: cmemoExecutablePath())
    }

    /// 可注入 cmemo 路径的纯函数版本，便于测试。
    static func snippet(for agent: String, cmemoPath: String) -> String? {
        guard agent == "claude-code" else { return nil }
        let cmemo = cmemoPath
        let root: [String: Any] = [
            "hooks": [
                "UserPromptSubmit": [
                    [
                        "hooks": [
                            [
                                "type": "command",
                                // jq 归一化 stdin 为统一协议 JSON，再管道给 cmemo record
                                "command": """
                                    jq -c '{agent:"claude-code",session_id:.session_id,cwd:.cwd,role:"user",content:.prompt,timestamp:(now|todate)}' | \(cmemo) record
                                    """,
                            ]
                        ]
                    ]
                ],
                "Stop": [
                    [
                        "hooks": [
                            [
                                "type": "command",
                                // stdin 原样透传给 claude-reply，由其自行解析（Task 7 接线）
                                "command": "\(cmemo) claude-reply",
                            ]
                        ]
                    ]
                ],
            ]
        ]
        // 结构恒为 JSON 安全字面量，序列化不会失败
        let data = try! JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    /// 打印 hook 配置片段；未知 agent 输出支持列表到 stderr 并返回 1。
    static func run(agent: String) -> Int32 {
        guard let snippet = snippet(for: agent) else {
            FileHandle.standardError.write(Data(
                "cmemo install: unsupported agent '\(agent)' (supported: \(supportedAgents.joined(separator: ", ")))\n".utf8))
            return 1
        }
        FileHandle.standardOutput.write(Data((snippet + "\n").utf8))
        return 0
    }

    /// 当前可执行文件绝对路径：CommandLine.arguments[0] 解析 symlink 得到 realpath。
    private static func cmemoExecutablePath() -> String {
        URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().path
    }
}
