import Foundation

public enum SessionEventError: Error {
    case invalidJSON
    case missingField(String)
    case invalidRole(String)
}

public struct SessionEvent: Codable, Equatable, Sendable {
    public enum Role: String, Codable, CaseIterable, Sendable {
        case user, assistant
    }

    public var agent: String
    public var sessionID: String
    public var cwd: String
    public var role: Role
    public var content: String
    public var timestamp: Date
    public var title: String?

    public init(agent: String, sessionID: String, cwd: String, role: Role,
                content: String, timestamp: Date, title: String? = nil) {
        self.agent = agent
        self.sessionID = sessionID
        self.cwd = cwd
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.title = title
    }

    private enum CodingKeys: String, CodingKey {
        case agent
        case sessionID = "session_id"
        case cwd
        case role
        case content
        case timestamp
        case title
    }

    public static func parse(_ data: Data, now: Date) throws -> SessionEvent {
        struct Payload: Decodable {
            var agent: String?
            var sessionID: String?
            var cwd: String?
            var role: String?
            var content: String?
            var timestamp: Date?
            var title: String?

            private enum CodingKeys: String, CodingKey {
                case agent
                case sessionID = "session_id"
                case cwd
                case role
                case content
                case timestamp
                case title
            }
        }

        let payload: Payload
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            payload = try decoder.decode(Payload.self, from: data)
        } catch {
            throw SessionEventError.invalidJSON
        }

        guard let agent = payload.agent else { throw SessionEventError.missingField("agent") }
        guard let sessionID = payload.sessionID else { throw SessionEventError.missingField("session_id") }
        guard let cwd = payload.cwd else { throw SessionEventError.missingField("cwd") }
        guard let roleString = payload.role else { throw SessionEventError.missingField("role") }
        guard let content = payload.content else { throw SessionEventError.missingField("content") }
        guard let role = Role(rawValue: roleString) else { throw SessionEventError.invalidRole(roleString) }

        return SessionEvent(
            agent: agent,
            sessionID: sessionID,
            cwd: cwd,
            role: role,
            content: content,
            timestamp: payload.timestamp ?? now,
            title: payload.title
        )
    }
}
