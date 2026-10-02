import Foundation

public struct SessionMeta: Codable, Equatable, Sendable {
    public var type: String = "meta"
    public var cwd: String
    public var createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case type
        case cwd
        case createdAt = "created_at"
    }
}

public struct SessionSummary: Equatable, Sendable {
    public var agent: String
    public var sessionID: String
    public var fileURL: URL
    public var cwd: String
    public var createdAt: Date
    public var lastActiveAt: Date
    public var messageCount: Int
    public var title: String
    public var isCorrupted: Bool

    init(agent: String, sessionID: String, fileURL: URL, cwd: String,
         createdAt: Date, lastActiveAt: Date, messageCount: Int,
         title: String, isCorrupted: Bool) {
        self.agent = agent
        self.sessionID = sessionID
        self.fileURL = fileURL
        self.cwd = cwd
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
        self.messageCount = messageCount
        self.title = title
        self.isCorrupted = isCorrupted
    }
}

public final class SessionStore {
    public let baseDirectory: URL

    public init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    public static func defaultBaseDirectory() -> URL {
        // CMEMO_BASE_DIR 供测试与高级用法覆盖默认存储位置。
        if let override = ProcessInfo.processInfo.environment["CMEMO_BASE_DIR"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CMemo/sessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static let allowedFilenameCharacters = Set(
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
    )

    public static func sanitizedSessionID(_ id: String) -> String {
        String(id.map { allowedFilenameCharacters.contains($0) ? $0 : "_" })
    }

    public func append(_ event: SessionEvent) throws -> URL {
        try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let url = baseDirectory.appendingPathComponent(
            "\(Self.sanitizedSessionID(event.agent))-\(Self.sanitizedSessionID(event.sessionID)).jsonl"
        )

        // 同名文件视为同一会话，继续追加（不加时间戳后缀）。
        if !FileManager.default.fileExists(atPath: url.path) {
            let meta = SessionMeta(cwd: event.cwd, createdAt: event.timestamp)
            // 先写临时文件再 rename，保证 meta 首行原子落盘。
            try Self.lineData(meta).write(to: url, options: .atomic)
        }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Self.lineData(event))
        return url
    }

    public func scan() throws -> [SessionSummary] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: baseDirectory.path) else { return [] }
        let files = try fm.contentsOfDirectory(
            at: baseDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        .filter { $0.pathExtension == "jsonl" }
        // 按文件容错：单个文件读取/解析失败（如半行写入、竞态消失）不击穿整次扫描。
        return files
            .compactMap { try? Self.summarize(fileURL: $0) }
            .sorted { $0.lastActiveAt > $1.lastActiveAt }
    }

    public func loadMessages(of summary: SessionSummary) throws -> [SessionEvent] {
        let text = try String(contentsOf: summary.fileURL, encoding: .utf8)
        let now = Date()
        return text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { try? SessionEvent.parse(Data($0.utf8), now: now) }
    }

    private static func summarize(fileURL: URL) throws -> SessionSummary {
        // lossy 解码：崩溃截断可能落在多字节字符中间，严格 UTF-8 会整文件抛错；
        // 换成逐字节替换 U+FFFD 后，行级容错（跳过坏行、isCorrupted）成为主防线。
        let data = (try? Data(contentsOf: fileURL)) ?? Data()
        let text = String(decoding: data, as: UTF8.self)
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        // 首行 meta：失败则整个文件视为损坏，cwd/createdAt 用文件修改时间兜底。
        var isCorrupted = false
        var meta: SessionMeta?
        if let first = lines.first, let parsed = decodeMeta(first) {
            meta = parsed
            lines.removeFirst()
        } else {
            isCorrupted = true
        }

        let modificationDate = try fileURL
            .resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
        let fallbackDate = modificationDate ?? Date()

        var events: [SessionEvent] = []
        let now = Date()
        for line in lines {
            if let event = try? SessionEvent.parse(Data(line.utf8), now: now) {
                events.append(event)
            } else {
                isCorrupted = true
            }
        }

        let createdAt = meta?.createdAt ?? fallbackDate
        let lastActiveAt = events.map(\.timestamp).max() ?? createdAt
        let title: String
        if let first = events.first {
            title = first.title ?? String(first.content.prefix(80))
        } else {
            title = ""
        }

        // agent/sessionID 优先取自首条消息，缺省时从文件名（agent-sessionID）兜底。
        let stem = fileURL.deletingPathExtension().lastPathComponent
        let filenameAgent: String
        let filenameSessionID: String
        if let dash = stem.firstIndex(of: "-") {
            filenameAgent = String(stem[..<dash])
            filenameSessionID = String(stem[stem.index(after: dash)...])
        } else {
            filenameAgent = stem
            filenameSessionID = stem
        }

        return SessionSummary(
            agent: events.first?.agent ?? filenameAgent,
            sessionID: events.first?.sessionID ?? filenameSessionID,
            fileURL: fileURL,
            cwd: meta?.cwd ?? "",
            createdAt: createdAt,
            lastActiveAt: lastActiveAt,
            messageCount: events.count,
            title: title,
            isCorrupted: isCorrupted
        )
    }

    private static func decodeMeta(_ line: String) -> SessionMeta? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SessionMeta.self, from: Data(line.utf8))
    }

    private static func lineData(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode(value)
        data.append(0x0A) // "\n"
        return data
    }
}
