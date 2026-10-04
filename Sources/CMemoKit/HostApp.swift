import Foundation

/// 会话的宿主应用信息：由 CLI 在落盘时刻沿进程链采集，写入 meta 首行。
public struct HostAppInfo: Codable, Equatable, Sendable {
    public var bundleID: String?
    public var name: String?

    public init(bundleID: String?, name: String?) {
        self.bundleID = bundleID
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case bundleID = "bundle_id"
        case name
    }

    /// 从进程可执行路径识别宿主应用：路径含 `.app` bundle 时读取其 Info.plist 的
    /// CFBundleIdentifier 与 CFBundleName；非 app bundle（如裸 CLI/node）仅保留可执行名。
    public static func fromProcessPath(_ path: String?) -> HostAppInfo? {
        guard let path, !path.isEmpty else { return nil }
        let executableName = (path as NSString).lastPathComponent

        guard let appURL = Self.appBundleURL(inExecutablePath: path),
              let bundle = Bundle(url: appURL) else {
            return HostAppInfo(bundleID: nil, name: executableName)
        }
        let bundleID = bundle.bundleIdentifier
        let displayName = bundle.infoDictionary?["CFBundleName"] as? String
        return HostAppInfo(bundleID: bundleID, name: displayName ?? executableName)
    }

    /// 从 `…/Foo.app/Contents/MacOS/exec` 形态的路径中定位 `Foo.app` 的 URL。
    private static func appBundleURL(inExecutablePath path: String) -> URL? {
        var url = URL(fileURLWithPath: path)
        while url.pathComponents.count > 1 {
            if url.pathExtension == "app" { return url }
            url.deleteLastPathComponent()
        }
        return nil
    }
}

/// 落盘时刻沿 PPID 链向上采集宿主应用。取最远端的 GUI app（离终端最近的那层
/// 反而可能是 shell/node 等中间进程）；采集失败时字段缺省，不影响记录本身。
public enum ProcessChainCollector {
    public static func collectHostApp(maxDepth: Int = 4) -> HostAppInfo? {
        var fallback: HostAppInfo?
        var pid = getppid()
        for _ in 0..<maxDepth {
            guard pid > 1, let path = executablePath(of: pid) else { break }
            if let host = HostAppInfo.fromProcessPath(path), host.bundleID != nil {
                return host
            }
            if fallback == nil, let bare = HostAppInfo.fromProcessPath(path) {
                fallback = bare
            }
            guard let next = parentPID(of: pid) else { break }
            pid = next
        }
        return fallback
    }

    private static func executablePath(of pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }

    private static func parentPID(of pid: pid_t) -> pid_t? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        let result = sysctl(&mib, 4, &info, &size, nil, 0)
        guard result == 0, size >= MemoryLayout<kinfo_proc>.stride else { return nil }
        let ppid = info.kp_eproc.e_ppid
        return ppid > 1 ? ppid : nil
    }
}

/// "Jump to Agent" 的解析结果：GUI agent 优先带 cwd 定位项目窗口，其余仅激活应用。
public enum JumpTarget: Equatable, Sendable {
    case app(bundleID: String)
    case projectWindow(scheme: String, url: URL, bundleID: String)

    public var isProjectWindow: Bool {
        if case .projectWindow = self { return true }
        return false
    }

    /// nil 表示无法跳转（无宿主信息或无 bundle id），UI 据此置灰菜单项。
    public static func resolve(hostApp: HostAppInfo?, cwd: String) -> JumpTarget? {
        guard let hostApp, let bundleID = hostApp.bundleID else { return nil }
        guard let scheme = projectWindowScheme(for: hostApp) else {
            return .app(bundleID: bundleID)
        }
        // cwd 逐字符百分号编码（保留 "/"），保证含空格/中文路径也能构成合法 URL。
        let encoded = cwd.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? cwd
        guard let url = URL(string: scheme + "file" + encoded) else {
            return .app(bundleID: bundleID)
        }
        return .projectWindow(scheme: scheme, url: url, bundleID: bundleID)
    }

    /// 已知支持 `scheme://file/<path>` 打开项目窗口的 agent 白名单；
    /// 按 bundle id 或应用名（不区分大小写）匹配，未匹配的宿主退化为仅激活应用。
    private static func projectWindowScheme(for host: HostAppInfo) -> String? {
        let identifiers = [host.bundleID, host.name].compactMap { $0?.lowercased() }
        let rules: [(keyword: String, scheme: String)] = [
            ("cursor", "cursor://"),
            ("trae", "trae://"),
            ("vscode", "vscode://"),
        ]
        for rule in rules where identifiers.contains { $0.contains(rule.keyword) } {
            return rule.scheme
        }
        return nil
    }
}
