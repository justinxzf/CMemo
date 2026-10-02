# CMemo 设计文档

日期：2026-10-03
状态：已与用户逐节确认

## 1. 背景与目标

CMemo 是一个 macOS 原生应用，用于**记录并浏览与 AI 编程工具（Claude Code / Trae / Cursor）的所有对话**。

核心需求（来自 PRD.md）：

1. 记录所有与 AI 对话的 Session
2. 功能区：多个功能组；功能组 1 = 按 agent 筛选对话（如选 cursor 只展示与 cursor 的会话）
3. 目录区：按文件目录分类，可看到哪些目录下有对话 session

成功标准：

- AI 工具通过 hook 自动上报对话，无需人工干预；App 未运行时也不丢数据
- App 中可按 agent 筛选会话，可按工作目录浏览会话
- 点击会话可查看完整对话内容（用户消息 + AI 回复，Markdown 渲染）

## 2. 总体架构

**方案 A（已确认）：CLI 落盘 + App 扫描**

```
┌─────────────┐   hook 触发    ┌──────────────┐   追加写入   ┌─────────────────────────────┐
│ AI 工具      │ ────────────→ │ cmemo record │ ──────────→ │ ~/Library/Application       │
│ (Claude Code │   stdin JSON  │ (CLI)        │   JSONL     │ Support/CMemo/sessions/     │
│ /Trae/Cursor)│               └──────────────┘             │   <agent>-<sessionId>.jsonl │
└─────────────┘                                            └──────────────┬──────────────┘
                                                                          │ 扫描+监听
                                                           ┌──────────────▼──────────────┐
                                                           │ CMemo App (SwiftUI)         │
                                                           │ CMemoKit: 索引/查询/模型      │
                                                           │ 三栏 UI: 目录│会话│内容       │
                                                           └─────────────────────────────┘
```

- 单个 Swift Package，三个 target：`CMemoKit`（共享库）、`cmemo`（CLI）、`CMemoApp`（macOS App）
- App 与 CLI 通过**文件系统**解耦，互不依赖运行状态
- App 使用文件监听（`DispatchSource`）实现近实时刷新

## 3. 组件设计

### 3.1 CMemoKit（共享库）

| 类型 | 职责 |
|---|---|
| `SessionEvent` | 统一事件模型：agent、session_id、cwd、role、content、timestamp、title（可选） |
| `SessionStore` | JSONL 读写：扫描 sessions 目录、追加写入、原子创建新会话文件 |
| `SessionIndex` | 内存索引：按 agent / 目录 / 关键词过滤，目录树构建 |

### 3.2 cmemo（CLI）

| 子命令 | 行为 |
|---|---|
| `cmemo record` | 读 stdin 单行 JSON → 校验归一化 → 追加写入对应 session 文件；首条消息时创建文件 |
| `cmemo install <agent>` | 输出各工具的 hook 配置片段（如 Claude Code settings.json 的 hooks 配置），`claude-code` 首版支持 |

### 3.3 CMemoApp（SwiftUI macOS App）

三栏 `NavigationSplitView`：

```
┌──────────────────────────────────────────────────────────────┐
│ 功能区  [功能组1: Agent 筛选]  (全部 | claude-code | trae | cursor) │
├──────────────┬───────────────────┬───────────────────────────┤
│ 目录 (sidebar)│ 会话列表           │ 会话内容                    │
│ ▾ /Users/x   │ ● 会话A  14:32     │ [user] 帮我实现xxx          │
│   ▾ AI       │   12条消息 cursor  │ [assistant] 好的，方案是... │
│     ▸ CMemo  │ ● 会话B  10:05     │                           │
│     ▸ Web    │   3条消息 claude   │ (Markdown 渲染)           │
│   ▸ Work     │ ...               │                           │
└──────────────┴───────────────────┴───────────────────────────┘
```

- **功能区**：顶部工具栏。功能组 1 = Agent 筛选（分段控件/标签，支持输入过滤）。架构预留功能组容器，后续可扩展功能组 2、3……
- **目录区**：按 cwd 构建目录树，仅展示有会话的目录；选中后中间列表联动过滤
- **会话列表**：标题（首条消息截断）、agent 标签、消息数、最后活跃时间，按时间倒序
- **会话内容**：user / assistant 气泡区分，Markdown 渲染

## 4. 数据协议与存储

### 4.1 通用协议 v1（stdin 单行 JSON）

```json
{
  "agent": "claude-code",
  "session_id": "abc123",
  "cwd": "/Users/x/AI/CMemo",
  "role": "user",
  "content": "消息正文",
  "timestamp": "2026-10-03T10:00:00+08:00",
  "title": "可选：会话标题"
}
```

必填：`agent`、`session_id`、`cwd`、`role`、`content`；`timestamp` 缺省时 CLI 补当前时间；`title` 可选。协议归一化在各工具 hook 配置侧完成（如 jq 转换），CLI 保持纯净。

### 4.2 存储格式

- 目录：`~/Library/Application Support/CMemo/sessions/`
- 每会话一个 JSONL 文件：`<agent>-<sessionId>.jsonl`
- 文件首行为元信息行：`{"type":"meta","cwd":"...","created_at":"..."}`
- 后续每行为一条消息行（统一协议 JSON，含 `role`、`content`、`timestamp`）
- 并发安全：单文件追加 + 原子重命名创建，无数据库
- App 启动全量扫描建索引，运行中靠文件监听增量刷新

## 5. 各工具适配

| 工具 | 接入方式 | 首版 |
|---|---|---|
| Claude Code | hooks：`UserPromptSubmit`（prompt/session_id/cwd）+ `Stop`（transcript_path 回读完整回复）；`cmemo install claude-code` 输出配置 | ✅ 完整支持 |
| Trae / Trae CN | 调研其 hook/自动化能力后接适配器 | 协议就绪，配置层待调研 |
| Cursor | hooks 能力有限，或需扩展/CLI 方式 | 留适配器接口，待调研 |

## 6. 错误处理

- stdin 非法 JSON / 缺必填字段：CLI 报错退出（码 1），不写半行
- 写入失败（磁盘等）：CLI 报错退出；hook 侧不重试（避免重复消息）
- App 遇损坏 JSONL 行：跳过该行，会话标记「部分数据损坏」，不中断
- session 文件名冲突：session_id 截断 + 时间戳后缀

## 7. 测试策略

- CMemoKit 单元测试：事件解析、JSONL 追加/扫描/索引、损坏行容错
- CLI 集成测试：管道喂 JSON，验证落盘内容
- App：ViewModel 层单元测试；UI 手动验收
- 端到端：`echo '<json>' | cmemo record` → App 索引可见

## 8. 范围外（YAGNI）

- 不做 App 内嵌 HTTP Server（方案 B 已否决）
- 不做云端同步、多设备
- 不做对话内容编辑/回写 AI 工具
- Trae / Cursor 的具体 hook 配置调研在接入阶段进行，不阻塞核心架构
