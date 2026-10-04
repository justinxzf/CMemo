import Foundation
import CMemoKit

enum RecordCommand {
    /// 解析 stdin 输入并追加到会话存储，返回进程退出码。
    /// 先解析后写盘：解析失败不触碰存储目录。
    static func run(input: Data, store: SessionStore, now: @autoclosure () -> Date) -> Int32 {
        let event: SessionEvent
        do {
            event = try SessionEvent.parse(input, now: now())
        } catch {
            FileHandle.standardError.write(Data("cmemo record: invalid input: \(error)\n".utf8))
            return 1
        }
        do {
            // 落盘时刻采集宿主应用（进程链），写入 meta 供 App「Jump to Agent」使用。
            _ = try store.append(event, hostApp: ProcessChainCollector.collectHostApp())
        } catch {
            FileHandle.standardError.write(Data("cmemo record: write failed: \(error)\n".utf8))
            return 1
        }
        return 0
    }
}
