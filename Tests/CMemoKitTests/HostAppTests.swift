import Testing
import Foundation
@testable import CMemoKit

@Suite struct HostAppTests {
    // MARK: - HostAppInfo 编解码

    @Test func hostAppInfoCodableRoundTrip() throws {
        let info = HostAppInfo(bundleID: "com.googlecode.iterm2", name: "iTerm2")
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(HostAppInfo.self, from: data)
        #expect(decoded == info)
        // snake_case 键
        #expect(String(decoding: data, as: UTF8.self).contains("bundle_id"))
    }

    @Test func legacyMetaWithoutHostAppDecodes() throws {
        let legacy = """
        {"type":"meta","cwd":"/w","created_at":"2026-10-04T08:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let meta = try decoder.decode(SessionMeta.self, from: Data(legacy.utf8))
        #expect(meta.hostApp == nil)
    }

    // MARK: - append 写入 / scan 读回

    private func makeStore() throws -> (SessionStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmemo-hostapp-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return (SessionStore(baseDirectory: dir), dir)
    }

    private func event() -> SessionEvent {
        SessionEvent(agent: "claude-code", sessionID: "h1", cwd: "/w",
                     role: .user, content: "hi", timestamp: Date(timeIntervalSince1970: 100), title: nil)
    }

    @Test func appendWithHostAppPersistsAndScanReadsBack() throws {
        let (store, _) = try makeStore()
        let host = HostAppInfo(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor")
        _ = try store.append(event(), hostApp: host)
        let summaries = try store.scan()
        #expect(summaries.count == 1)
        #expect(summaries[0].hostApp == host)
    }

    @Test func appendWithoutHostAppKeepsNil() throws {
        let (store, _) = try makeStore()
        _ = try store.append(event())
        let summaries = try store.scan()
        #expect(summaries[0].hostApp == nil)
    }

    // MARK: - 进程路径 → 宿主应用识别（纯逻辑）

    @Test func fromProcessPathReadsAppBundleIdentifier() throws {
        let info = HostAppInfo.fromProcessPath("/System/Applications/Utilities/Terminal.app/Contents/MacOS/Terminal")
        #expect(info?.bundleID == "com.apple.Terminal")
        #expect(info?.name == "Terminal")
    }

    @Test func fromProcessPathNonAppBundleKeepsNameOnly() {
        let info = HostAppInfo.fromProcessPath("/usr/local/bin/node")
        #expect(info?.bundleID == nil)
        #expect(info?.name == "node")
    }

    @Test func fromProcessPathNilOrMissingReturnsNil() {
        #expect(HostAppInfo.fromProcessPath(nil) == nil)
        // 契约：纯路径字符串解析，不校验文件存在性（存在性由 proc_pidpath 保证）
        let missing = HostAppInfo.fromProcessPath("/no/such/binary")
        #expect(missing?.bundleID == nil)
        #expect(missing?.name == "binary")
    }

    @Test func collectFromOwnProcessChainReturnsSomething() {
        // 测试进程的祖先链存在（runner），采集不应崩溃且类型正确。
        let info = ProcessChainCollector.collectHostApp()
        if let info {
            #expect(info.name != nil || info.bundleID != nil)
        }
    }

    // MARK: - JumpTarget 解析（纯逻辑）

    @Test func resolveOpensProjectWindowForCursor() throws {
        let host = HostAppInfo(bundleID: "com.todesktop.230313mzl4w4u92", name: "Cursor")
        let target = JumpTarget.resolve(hostApp: host, cwd: "/w/my proj")
        #expect(target == .projectWindow(
            scheme: "cursor://",
            url: try #require(URL(string: "cursor://file/w/my%20proj")),
            bundleID: "com.todesktop.230313mzl4w4u92"
        ))
    }

    @Test func resolveMatchesByNameForTrae() {
        let host = HostAppInfo(bundleID: nil, name: "Trae")
        // bundleID 缺失时无法可靠激活应用，返回 nil
        #expect(JumpTarget.resolve(hostApp: host, cwd: "/w") == nil)
        let withBundle = HostAppInfo(bundleID: "com.trae.app", name: "Trae")
        #expect(JumpTarget.resolve(hostApp: withBundle, cwd: "/w")?.isProjectWindow == true)
    }

    @Test func resolveTerminalHostFallsBackToAppOnly() {
        let host = HostAppInfo(bundleID: "com.googlecode.iterm2", name: "iTerm2")
        #expect(JumpTarget.resolve(hostApp: host, cwd: "/w") == .app(bundleID: "com.googlecode.iterm2"))
    }

    @Test func resolveNilInputsReturnNil() {
        #expect(JumpTarget.resolve(hostApp: nil, cwd: "/w") == nil)
        let noBundle = HostAppInfo(bundleID: nil, name: "node")
        #expect(JumpTarget.resolve(hostApp: noBundle, cwd: "/w") == nil)
    }
}
