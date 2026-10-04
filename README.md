# CMemo

CMemo 是一个通过 agent hook 自动记录所有 AI 对话 session 的 macOS 应用。`cmemo` CLI 接收 hook 注入的 JSON 并落盘为 JSONL，`CMemoApp`（SwiftUI）扫描同一目录建立内存索引，提供按 agent 筛选、按目录浏览、全文搜索和完整对话回看。

```
AI agent hook ──stdin JSON──▶ cmemo record ──▶ ~/Library/Application Support/CMemo/sessions/*.jsonl
                                                                      ▲
                                                    CMemoApp 扫描 + 文件监听（近实时刷新）
```

## 功能

- **自动记录**：Claude Code 的 Stop hook 触发即落盘，无需手动操作；App 未运行期间照样追加，不丢数据
- **三栏浏览**：目录树（长路径自动折叠）→ 会话列表（相对时间倒序）→ 对话详情（Markdown 渲染气泡）
- **多层过滤**：Agent 筛选 × 目录联动 × 关键字全文搜索（标题 + 消息内容，不区分大小写，输入防抖）
- **容错读取**：损坏行跳过并标记 `isCorrupted`，单文件损坏不影响整体索引

## 系统要求

- macOS 13+
- Swift 5.9+（零第三方依赖，无需 Xcode，SwiftPM 命令行工具链即可）

## 构建与运行

```bash
swift build            # 编译
swift test             # 运行全部测试（swift-testing）
swift run CMemoApp     # 启动桌面应用
```

## 接入 Claude Code

1. 生成 hooks 配置片段（自动填入 cmemo 可执行文件路径）：

   ```bash
   swift run cmemo install claude-code
   ```

2. 将输出的 JSON 片段合并进 `~/.claude/settings.json`（依赖系统 `jq`）。
3. 之后每轮对话结束时，最后一条 assistant 回复会自动写入对应会话文件。

> 提示：debug 构建产物路径随重新编译变化；日常使用建议 `swift build -c release` 后使用 release 路径。

### CLI 命令

| 命令 | 用途 |
|---|---|
| `cmemo record` | 从 stdin 读取 hook JSON，校验后追加写入会话文件 |
| `cmemo install <agent>` | 输出指定 agent 可直接粘入 settings.json 的 hooks 配置 |
| `cmemo claude-reply` | 处理 Claude Code Stop hook 载荷，取最后一条 assistant 回复落盘 |

## 数据存储

- 默认目录：`~/Library/Application Support/CMemo/sessions/`
- 环境变量 `CMEMO_BASE_DIR` 可覆盖存储目录（调试/多实例场景）
- 会话文件名：`<agent>-<sanitized(session_id)>.jsonl`（特殊字符替换为 `_`，防路径穿越）
- 文件格式：首行 meta（`cwd`、`created_at`），后续每行一条统一协议消息（`agent`/`session_id`/`cwd`/`role`/`content`/`timestamp`/`title`，snake_case，ISO8601 时间戳）

清理测试/mock 数据（session ID 含 `mock-` 前缀的演示数据）：

```bash
rm "$HOME/Library/Application Support/CMemo/sessions/"*mock*.jsonl
```

## App 使用

| 操作 | 说明 |
|---|---|
| 左栏目录树 | 点击节点按目录前缀过滤会话；无会话的中间层自动折叠（如 `A/B/C/D`） |
| 中栏顶部过滤条 | Agent 下拉筛选 + 搜索框（全文检索，250ms 防抖） |
| 右栏详情 | 顶部信息卡（Session ID / Agent / 开启时间 / 会话地址，均可复制），下方对话气泡 |
| 刷新 | 文件监听自动刷新；⌘R 手动重扫 |

## 项目结构

```
Sources/
├── CMemoKit/        # 核心库：SessionEvent（协议解析）、SessionStore（读写）、
│                    # SessionIndex（过滤/目录树/全文搜索）、DirectoryWatcher（文件监听）、
│                    # ClaudeTranscript（Claude 回复提取）、MarkdownBlocks（块级 Markdown 解析）
├── cmemo/           # CLI：record / install / claude-reply
└── CMemoApp/        # SwiftUI 三栏应用
Tests/CMemoKitTests/ # swift-testing 单元测试与端到端用例
```

## 设计文档

- PRD：`PRD.md`
- 设计规格：`docs/superpowers/specs/2026-10-03-cmemo-design.md`
- 实施计划：`docs/superpowers/plans/2026-10-03-cmemo.md`
