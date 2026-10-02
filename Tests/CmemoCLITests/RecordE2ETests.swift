import Testing
import Foundation

@Suite
final class RecordE2ETests {
    // 测试文件位于 Tests/CmemoCLITests/，向上三层到仓库根。
    private static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private let dir: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cmemo-e2e-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: dir)
    }

    private func binPath() throws -> String {
        let out = Process()
        out.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        out.arguments = ["bash", "-lc", "cd \(Self.packageRoot.path) && swift build --show-bin-path"]
        let pipe = Pipe()
        out.standardOutput = pipe
        try out.run()
        out.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func recordProcess() throws -> Process {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: try binPath()).appendingPathComponent("cmemo")
        p.arguments = ["record"]
        p.environment = ["CMEMO_BASE_DIR": dir.path]
        return p
    }

    @Test
    func recordWritesSessionFileAndExitZero() throws {
        let p = try recordProcess()
        let inPipe = Pipe()
        p.standardInput = inPipe
        let errPipe = Pipe()
        p.standardError = errPipe
        try p.run()
        try inPipe.fileHandleForWriting.write(contentsOf: Data(
            #"{"agent":"claude-code","session_id":"e2e","cwd":"/tmp","role":"user","content":"hello"}"#.utf8))
        inPipe.fileHandleForWriting.closeFile()
        p.waitUntilExit()
        #expect(p.terminationStatus == 0)
        let file = dir.appendingPathComponent("claude-code-e2e.jsonl")
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(try String(contentsOf: file, encoding: .utf8)
            .split(separator: "\n", omittingEmptySubsequences: true).count == 2)
    }

    @Test
    func recordBadJSONExitsOneWithoutCreatingFile() throws {
        let p = try recordProcess()
        let inPipe = Pipe()
        p.standardInput = inPipe
        let errPipe = Pipe()
        p.standardError = errPipe
        try p.run()
        try inPipe.fileHandleForWriting.write(contentsOf: Data("".utf8))
        inPipe.fileHandleForWriting.closeFile()
        p.waitUntilExit()
        let stderr = String(decoding: errPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        #expect(p.terminationStatus == 1)
        #expect(try FileManager.default.contentsOfDirectory(atPath: dir.path) == [])
        #expect(!stderr.isEmpty) // 错误信息输出到 stderr
    }
}
