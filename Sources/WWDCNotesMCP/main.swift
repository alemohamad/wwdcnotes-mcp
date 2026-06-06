import Foundation
import MCP

// MARK: - Session model

struct Session: Decodable {
    let id: String
    let year: Int
    let code: String
    let title: String
    let description: String?
    let permalink: String?
    let lengthInMinutes: Int?
    let relatedSessionIDs: [String]

    /// Mirrors the fileName computed property from Session.swift in the WWDCNotes repo.
    /// Pattern: WWDC{YY}-{code}-{normalizedTitle}
    var fileName: String {
        let yearSuffix = year - 2000
        let yearPrefix = "WWDC\(yearSuffix)"

        var normalized = title
            .replacingOccurrences(of: " & ", with: " and ")

        // Strip diacritics
        normalized = normalized.folding(
            options: [.diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en-US")
        )

        // Remove punctuation (keep alphanumerics, spaces, hyphens)
        normalized = normalized
            .unicodeScalars
            .filter { scalar in
                CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-"))
                    .contains(scalar)
            }
            .reduce("") { $0 + String($1) }

        // Collapse whitespace into hyphens
        let parts = normalized.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        normalized = parts.joined(separator: "-")

        return "\(yearPrefix)-\(code)-\(normalized)"
    }

    var rawNoteURL: URL {
        let yearSuffix = year - 2000
        let yearFolder = "WWDC\(yearSuffix)"
        let base = "https://raw.githubusercontent.com/WWDCNotes/WWDCNotes/main/Sources/WWDCNotes/WWDCNotes.docc"
        return URL(string: "\(base)/\(yearFolder)/\(fileName).md")!
    }

    var webURL: String {
        let base = "https://wwdcnotes.com/documentation/wwdcnotes"
        return "\(base)/\(fileName.lowercased())"
    }

    var durationLabel: String {
        guard let mins = lengthInMinutes else { return "" }
        return " (\(mins) min)"
    }
}

// MARK: - Session cache

actor SessionCache {
    private var sessions: [String: Session]?
    private var fetchedAt: Date?
    private let ttl: TimeInterval = 600 // 10 minutes

    static let shared = SessionCache()

    private let indexURL = URL(string:
        "https://raw.githubusercontent.com/WWDCNotes/WWDCNotes/main/Sources/Sessions/sessions.json"
    )!

    func get() async throws -> [String: Session] {
        if let cached = sessions, let date = fetchedAt, Date().timeIntervalSince(date) < ttl {
            return cached
        }
        let (data, _) = try await URLSession.shared.data(from: indexURL)
        let decoded = try JSONDecoder().decode([String: Session].self, from: data)
        sessions = decoded
        fetchedAt = Date()
        return decoded
    }
}

// MARK: - Helpers

func isStub(_ content: String) -> Bool {
    content.contains("No Overview Available!")
}

func textContent(_ string: String) -> Tool.Content {
    .text(text: string, annotations: nil, _meta: nil)
}

// MARK: - Tool definitions

let toolSearchSessions = Tool(
    name: "search_sessions",
    description: "Search WWDC session titles and descriptions by keyword. Returns matching sessions with their IDs and wwdcnotes.com URLs.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "query": .object([
                "type": .string("string"),
                "description": .string("Keywords to search, e.g. 'Foundation Models', 'Swift concurrency', 'SwiftData'"),
            ]),
            "year": .object([
                "type": .string("number"),
                "description": .string("Filter to a specific WWDC year, e.g. 2025. Omit to search all years."),
            ]),
            "limit": .object([
                "type": .string("number"),
                "description": .string("Max results to return (default 10, max 25)"),
            ]),
        ]),
        "required": .array([.string("query")]),
    ])
)

let toolGetSessionNotes = Tool(
    name: "get_session_notes",
    description: "Fetch the full community-written notes for a WWDC session. Pass the session ID from search_sessions (e.g. 'wwdc2025-286') or provide year + code. Always show the WWDCNotes URL to the user so they can read more at wwdcnotes.com.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "session_id": .object([
                "type": .string("string"),
                "description": .string("Session ID like 'wwdc2024-10136' or 'wwdc2025-286'"),
            ]),
            "year": .object([
                "type": .string("number"),
                "description": .string("WWDC year, e.g. 2024. Use with 'code' if not using session_id."),
            ]),
            "code": .object([
                "type": .string("string"),
                "description": .string("Session code, e.g. '10136'. Use with 'year' if not using session_id."),
            ]),
        ]),
    ])
)

let toolListSessions = Tool(
    name: "list_sessions",
    description: "List all WWDC sessions for a given year, sorted by session code.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "year": .object([
                "type": .string("number"),
                "description": .string("WWDC year, e.g. 2025"),
            ]),
        ]),
        "required": .array([.string("year")]),
    ])
)

let toolGetRelatedSessions = Tool(
    name: "get_related_sessions",
    description: "Get the list of sessions Apple recommends watching alongside a given session.",
    inputSchema: .object([
        "type": .string("object"),
        "properties": .object([
            "session_id": .object([
                "type": .string("string"),
                "description": .string("Session ID like 'wwdc2024-10136'"),
            ]),
        ]),
        "required": .array([.string("session_id")]),
    ])
)

// MARK: - Tool handlers

func handleSearchSessions(_ params: CallTool.Parameters) async throws -> CallTool.Result {
    guard let query = params.arguments?["query"]?.stringValue, !query.isEmpty else {
        return .init(content: [textContent("Missing required parameter: query")])
    }

    let year = params.arguments?["year"].flatMap { v -> Int? in
        if case .int(let n) = v { return n }
        if case .double(let n) = v { return Int(n) }
        return nil
    }
    let limitArg = params.arguments?["limit"].flatMap { v -> Int? in
        if case .int(let n) = v { return n }
        if case .double(let n) = v { return Int(n) }
        return nil
    }
    let limit = min(limitArg ?? 10, 25)

    let sessions = try await SessionCache.shared.get()
    let q = query.lowercased()

    var matches = sessions.values.filter { s in
        if let y = year, s.year != y { return false }
        return s.title.lowercased().contains(q)
            || (s.description ?? "").lowercased().contains(q)
    }

    // Sort: title matches first, then most recent
    matches.sort { a, b in
        let aTitle = a.title.lowercased().contains(q)
        let bTitle = b.title.lowercased().contains(q)
        if aTitle != bTitle { return aTitle }
        return a.year > b.year
    }

    let top = Array(matches.prefix(limit))

    if top.isEmpty {
        let yearLabel = year.map { " in \($0)" } ?? ""
        return .init(content: [textContent("No sessions found for query: \"\(query)\"\(yearLabel).")])
    }

    var lines = ["Found \(matches.count) session\(matches.count == 1 ? "" : "s") (showing \(top.count)):", ""]
    for s in top {
        let desc = s.description ?? ""
        let truncated = desc.count > 120 ? String(desc.prefix(120)) + "…" : desc
        lines.append("• [\(s.id)] WWDC\(s.year) \(s.code) — \(s.title)\(s.durationLabel)")
        lines.append("  🔗 \(s.webURL)")
        if !truncated.isEmpty {
            lines.append("  \(truncated)")
        }
    }

    return .init(content: [textContent(lines.joined(separator: "\n"))])
}

func handleGetSessionNotes(_ params: CallTool.Parameters) async throws -> CallTool.Result {
    let sessions = try await SessionCache.shared.get()

    var session: Session?

    if let sid = params.arguments?["session_id"]?.stringValue {
        session = sessions[sid] ?? sessions[sid.lowercased()]
        // Fallback: case-insensitive search
        if session == nil {
            session = sessions.values.first { $0.id.lowercased() == sid.lowercased() }
        }
    } else if let yearVal = params.arguments?["year"],
              let codeVal = params.arguments?["code"]?.stringValue {
        var yearInt: Int?
        if case .int(let n) = yearVal { yearInt = n }
        if case .double(let n) = yearVal { yearInt = Int(n) }
        if let y = yearInt {
            let id = "wwdc\(y)-\(codeVal)"
            session = sessions[id]
        }
    }

    guard let session else {
        return .init(content: [textContent("Session not found. Use search_sessions or list_sessions to find a valid session ID.")])
    }

    let (data, response) = try await URLSession.shared.data(from: session.rawNoteURL)
    let httpResponse = response as? HTTPURLResponse

    guard httpResponse?.statusCode == 200, let content = String(data: data, encoding: .utf8) else {
        return .init(content: [textContent("""
            Could not fetch notes for: \(session.title) (\(session.id))
            HTTP \(httpResponse?.statusCode ?? 0) - no community notes file found on GitHub.
            Web URL: \(session.webURL)
            """)])
    }

    let stub = isStub(content)
    var header = [
        "# \(session.title)",
        "WWDC\(session.year) · Session \(session.code)\(session.durationLabel)",
        "Apple video: \(session.permalink ?? "N/A")",
        "WWDCNotes: \(session.webURL)",
    ]
    if stub {
        header.append("⚠️  No community notes yet — only a stub is available.")
    }
    header.append("---")

    return .init(content: [textContent(header.joined(separator: "\n") + "\n\n" + content)])
}

func handleListSessions(_ params: CallTool.Parameters) async throws -> CallTool.Result {
    guard let yearVal = params.arguments?["year"] else {
        return .init(content: [textContent("Missing required parameter: year")])
    }
    var n: Double = 0
    if case .int(let i) = yearVal { n = Double(i) }
    else if case .double(let d) = yearVal { n = d }
    else {
        return .init(content: [textContent("Missing required parameter: year")])
    }
    let year = Int(n)

    let sessions = try await SessionCache.shared.get()
    var yearSessions = sessions.values.filter { $0.year == year }
    yearSessions.sort { a, b in
        (Int(a.code) ?? 0) < (Int(b.code) ?? 0)
    }

    if yearSessions.isEmpty {
        let years = Set(sessions.values.map(\.year)).sorted(by: >)
        return .init(content: [textContent("No sessions for \(year). Available years: \(years.map(String.init).joined(separator: ", "))")])
    }

    var lines = ["WWDC\(year) - \(yearSessions.count) sessions:", ""]
    for s in yearSessions {
        lines.append("• [\(s.id)] \(s.code) - \(s.title)\(s.durationLabel)")
        lines.append("  🔗 \(s.webURL)")
    }

    return .init(content: [textContent(lines.joined(separator: "\n"))])
}

func handleGetRelatedSessions(_ params: CallTool.Parameters) async throws -> CallTool.Result {
    guard let sid = params.arguments?["session_id"]?.stringValue else {
        return .init(content: [textContent("Missing required parameter: session_id")])
    }

    let sessions = try await SessionCache.shared.get()
    guard let session = sessions[sid] ?? sessions.values.first(where: { $0.id.lowercased() == sid.lowercased() }) else {
        return .init(content: [textContent("Session '\(sid)' not found.")])
    }

    guard !session.relatedSessionIDs.isEmpty else {
        return .init(content: [textContent("No related sessions listed for: \(session.title) (\(sid))")])
    }

    var lines = ["Related sessions for: \(session.title) (\(sid))", ""]
    for relatedID in session.relatedSessionIDs {
        if let related = sessions[relatedID] {
            lines.append("• [\(related.id)] WWDC\(related.year) \(related.code) - \(related.title)\(related.durationLabel)")
            lines.append("  🔗 \(related.webURL)")
        } else {
            lines.append("• \(relatedID) (not in index)")
        }
    }

    return .init(content: [textContent(lines.joined(separator: "\n"))])
}

// MARK: - Entry point

let server = Server(
    name: "wwdcnotes",
    version: "1.0.0",
    capabilities: .init(tools: .init(listChanged: false))
)

let transport = StdioTransport()
try await server.start(transport: transport)

await server.withMethodHandler(ListTools.self) { _ in
    .init(tools: [
        toolSearchSessions,
        toolGetSessionNotes,
        toolListSessions,
        toolGetRelatedSessions,
    ])
}

await server.withMethodHandler(CallTool.self) { params in
    switch params.name {
    case "search_sessions":      return try await handleSearchSessions(params)
    case "get_session_notes":    return try await handleGetSessionNotes(params)
    case "list_sessions":        return try await handleListSessions(params)
    case "get_related_sessions": return try await handleGetRelatedSessions(params)
    default:
        throw MCPError.invalidParams("Unknown tool: \(params.name)")
    }
}

await server.waitUntilCompleted()
