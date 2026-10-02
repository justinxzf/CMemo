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

public final class SessionStore {
    public let baseDirectory: URL

    public init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    public static func defaultBaseDirectory() -> URL {
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
            "\(event.agent)-\(Self.sanitizedSessionID(event.sessionID)).jsonl"
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

    private static func lineData(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var data = try encoder.encode(value)
        data.append(0x0A) // "\n"
        return data
    }
}
