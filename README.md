# wwdcnotes-mcp

An MCP server written in Swift that gives any MCP-compatible client access to community WWDC session notes from [WWDC Notes](https://wwdcnotes.com).

Data is fetched directly from the public [WWDCNotes GitHub repo](https://github.com/WWDCNotes/WWDCNotes). No API keys needed.

---

## Install options

### Mint

```bash
mint install alemohamad/wwdcnotes-mcp@main
```

To update, you need to uninstall and reinstall the MCP.

To uninstall:

```bash
mint uninstall wwdcnotes-mcp
```

> Note: If you don't have Mint: `brew install mint`

### Build from source

```bash
git clone https://github.com/alemohamad/wwdcnotes-mcp.git
cd wwdcnotes-mcp
swift build -c release
cp .build/release/wwdcnotes-mcp /usr/local/bin/
```

To update, `git pull` and re-run the build and copy commands.

To uninstall, remove the binary manually (e.g. `rm /usr/local/bin/wwdcnotes-mcp`).

---

## Tools

| Tool | Description |
|------|-------------|
| `search_sessions` | Search session titles and descriptions by keyword, optionally filtered by year |
| `get_session_notes` | Fetch the full community notes for a session (by ID or year + code) |
| `list_sessions` | List all sessions for a given year |
| `get_related_sessions` | Get Apple's recommended related sessions |

---

## Requirements

- **macOS 14+**
- **Swift 5.10+** (comes with Xcode 15.3+)

---

## Client setup

This server uses **stdio transport**, so it works with any MCP client. After installing the binary, register it with your client of choice:

### Claude Code

```bash
claude mcp add --scope user --transport stdio wwdcnotes wwdcnotes-mcp
```

To remove:

```bash
claude mcp remove wwdcnotes
```

### Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "wwdcnotes": {
      "command": "wwdcnotes-mcp",
      "args": []
    }
  }
}
```

### Xcode (Intelligence)

Add the MCP server in **Xcode > Settings > Intelligence > MCP Servers** with the command `wwdcnotes-mcp`.

### Gemini CLI

Edit `~/.gemini/settings.json`:

```json
{
  "mcpServers": {
    "wwdcnotes": {
      "command": "wwdcnotes-mcp",
      "args": []
    }
  }
}
```

### VS Code (Copilot)

Edit `.vscode/mcp.json` in your project:

```json
{
  "servers": {
    "wwdcnotes": {
      "command": "wwdcnotes-mcp",
      "args": []
    }
  }
}
```

### Other clients

Any MCP-compatible client (Cursor, Windsurf, etc.) can connect using the command `wwdcnotes-mcp` with stdio transport.

Restart your client after adding the server.

---

## Usage examples

Once connected, ask things like:

- *"Search for WWDC 2025 sessions about Foundation Models"*
- *"Is there a good WWDC talk about in-app purchases?"*
- *"Get the notes for wwdc2025-286"*
- *"List all WWDC 2025 sessions"*
- *"What sessions are related to wwdc2024-10136?"*

---

## How it works

The session index (~2,183 sessions from WWDC 2012-2025) is fetched from GitHub and cached in memory for 10 minutes. Notes are fetched as raw Markdown at runtime.

Sessions with no community notes yet contain a stub. The tool warns you when that's the case so the agent doesn't hallucinate content.

Uses **stdio transport** -- no server process or open port needed.
