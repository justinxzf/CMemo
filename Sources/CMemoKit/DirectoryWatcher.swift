import Foundation

/// 目录监听器：监听目录自身的写入事件（子文件创建/修改/删除），
/// 0.5s 防抖后在私有串行队列上回调 onChange（调用方自行处理线程跳转）。
public final class DirectoryWatcher {
    private let path: String
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "com.cmemo.DirectoryWatcher")
    private var source: DispatchSourceFileSystemObject?
    private var debounceWorkItem: DispatchWorkItem?

    public init(path: URL, onChange: @escaping () -> Void) {
        self.path = path.path
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    /// 开始监听；重复调用会先停止旧监听。
    public func start() {
        stop()
        queue.sync {
            let fd = open(path, O_EVTONLY) // 目录描述符，事件掩码用 .write 覆盖内容/条目变化
            guard fd >= 0 else { return }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: .write,
                queue: queue
            )
            source.setEventHandler { [weak self] in
                guard let self else { return }
                self.debounceWorkItem?.cancel()
                let item = DispatchWorkItem(qos: .utility) { [onChange = self.onChange] in
                    onChange()
                }
                self.debounceWorkItem = item
                self.queue.asyncAfter(deadline: .now() + 0.5, execute: item)
            }
            // fd 的关闭统一放在 cancel handler，保证恰好关闭一次。
            source.setCancelHandler { [fd] in
                close(fd)
            }
            self.source = source
            source.resume()
        }
    }

    /// 停止监听并释放资源；幂等，可安全重复调用。
    public func stop() {
        queue.sync {
            debounceWorkItem?.cancel()
            debounceWorkItem = nil
            source?.cancel() // cancel handler 负责关闭 fd
            source = nil
        }
    }
}
