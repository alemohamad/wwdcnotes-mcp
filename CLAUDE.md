# CLAUDE.md

## Project overview

**wwdcnotes-mcp** is an MCP (Model Context Protocol) server written in Swift that provides access to community WWDC session notes from wwdcnotes.com. It communicates over stdio transport and is designed to be used with Claude Code, Claude Desktop, or any MCP client.

Data is fetched from the public [WWDCNotes GitHub repo](https://github.com/WWDCNotes/WWDCNotes) — no API keys needed.

## Architecture

Single-file executable (`Sources/WWDCNotesMCP/main.swift`) with:
- **Session model** — Decodable struct matching the WWDCNotes `sessions.json` schema, includes `fileName` generation logic mirroring the upstream repo
- **SessionCache** — Actor-based in-memory cache with 10-minute TTL, fetches session index from GitHub
- **4 MCP tools** — `search_sessions`, `get_session_notes`, `list_sessions`, `get_related_sessions`
- **MCP server** — Uses `swift-sdk` (MCP Swift SDK v0.11+), stdio transport, registers tool handlers

## Tech stack

- Swift 6.0+ / macOS 14+
- Swift Package Manager
- Dependency: `modelcontextprotocol/swift-sdk` (MCP SDK)

## Build & run

```bash
swift build -c release
# Binary: .build/release/wwdcnotes-mcp
```

## Key patterns

- Session notes are fetched as raw Markdown from GitHub at runtime (`raw.githubusercontent.com`)
- Session file names are derived from titles using normalization: `& → and`, strip diacritics, remove punctuation, hyphenate spaces, prefix with `WWDC{YY}-{code}-`
- Stub detection: notes containing "No Overview Available!" are flagged as not yet written
- The session index URL: `https://raw.githubusercontent.com/WWDCNotes/WWDCNotes/main/Sources/Sessions/sessions.json`
