import Testing
import Foundation
@testable import CMemoKit

/// 目录监听回调时序测试：启动后向目录写入文件，onChange 应在窗口内触发。
@Suite
final class SessionIndexReloadTests {
    private var dir: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmemo-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: dir)
    }

    /// 跨线程安全的「已触发」标记，供轮询循环提前退出。
    private final class ChangeFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var changed = false
        var isChanged: Bool { lock.withLock { changed } }
        func mark() { lock.withLock { changed = true } }
    }

    @Test
    func writeFileAfterStartFiresOnChangeWithinFiveSeconds() async throws {
        let flag = ChangeFlag()
        try await confirmation("启动后 2s 内写入文件，onChange 在 5s 内触发") { confirm in
            let watcher = DirectoryWatcher(path: dir) {
                confirm() // 先确认再置位，保证 confirmation 结束前已被调用
                flag.mark()
            }
            watcher.start()
            defer { watcher.stop() }

            // 启动后 2s 内向目录写入一个会话文件（brief 规定的时间窗口）
            try await Task.sleep(for: .milliseconds(200))
            try Data("meta\n".utf8).write(
                to: dir.appendingPathComponent("claude-code-watch-1.jsonl"))

            // 有界轮询最多 5s；0.5s 防抖后通常立即触发，超时未触发则干净失败
            for _ in 0..<50 where !flag.isChanged {
                try await Task.sleep(for: .milliseconds(100))
            }
        }
    }
}
