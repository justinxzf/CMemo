import Testing
import Foundation
@testable import CMemoKit

private enum ISODate {
    static let fmt = ISO8601DateFormatter()
}

@Suite
struct SessionEventTests {
    private let base = """
    {"agent":"claude-code","session_id":"abc","cwd":"/tmp/p","role":"user","content":"hi"}
    """.data(using: .utf8)!

    @Test
    func parseDecodesSnakeCaseAndDefaultsTimestamp() throws {
        let fixed = Date(timeIntervalSince1970: 100)
        let e = try SessionEvent.parse(base, now: fixed)
        #expect(e.agent == "claude-code")
        #expect(e.sessionID == "abc")
        #expect(e.role == .user)
        #expect(e.timestamp == fixed)
        #expect(e.title == nil)
    }

    @Test
    func parseKeepsProvidedTimestampAndTitle() throws {
        let json = """
        {"agent":"cursor","session_id":"s1","cwd":"/w","role":"assistant","content":"ok","timestamp":"2026-10-03T10:00:00+08:00","title":"t"}
        """.data(using: .utf8)!
        let e = try SessionEvent.parse(json, now: Date())
        let expectedTimestamp = try #require(ISODate.fmt.date(from: "2026-10-03T10:00:00+08:00"))
        #expect(e.timestamp == expectedTimestamp)
        #expect(e.title == "t")
    }

    @Test
    func parseRejectsMissingRequiredField() {
        let bad = """
        {"agent":"cursor","session_id":"s1","role":"user","content":"hi"}
        """.data(using: .utf8)!
        do {
            _ = try SessionEvent.parse(bad, now: Date())
            Issue.record("expected SessionEventError.missingField, but parse succeeded")
        } catch {
            guard case SessionEventError.missingField(let f) = error else {
                Issue.record("expected .missingField, got \(error)")
                return
            }
            #expect(f == "cwd")
        }
    }

    @Test
    func parseRejectsInvalidJSONAndRole() {
        #expect(throws: SessionEventError.self) {
            try SessionEvent.parse(Data("not json".utf8), now: Date())
        }
        let badRole = """
        {"agent":"a","session_id":"s","cwd":"/w","role":"system","content":"x"}
        """.data(using: .utf8)!
        #expect(throws: SessionEventError.self) {
            try SessionEvent.parse(badRole, now: Date())
        }
    }
}
