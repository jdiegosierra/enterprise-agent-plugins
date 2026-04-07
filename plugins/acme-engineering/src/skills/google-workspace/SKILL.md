---
name: google-workspace
description: >
  Google Workspace CLI (gws) reference. Covers installation, authentication,
  command structure, and common operations for Drive, Gmail, Calendar, Sheets,
  Docs, Chat, and Admin APIs. Consult this skill when interacting with Google
  Workspace services.
metadata:
  based_on: googleworkspace/cli
---

# Google Workspace CLI (gws)

## Installation

```bash
npm install -g @googleworkspace/cli
```

Verify: `gws --version`

## Authentication

```bash
# Interactive OAuth login (opens browser)
gws auth login

# Service account authentication
gws auth login --service-account --credentials-file /path/to/service-account.json

# Using a pre-obtained access token
gws auth login --access-token <token>
```

Check auth status: `gws auth status`

## Command structure

```
gws <service> <resource> <action> [flags]
```

The CLI dynamically builds commands from Google's Discovery Service — new API endpoints are available automatically.

## Common operations

### Google Drive

```bash
# List files
gws drive files list --page-all

# Search files
gws drive files list --q "name contains 'report'"

# Get file metadata
gws drive files get --fileId <file-id>

# Upload a file
gws drive files create --upload /path/to/file.pdf --name "report.pdf"

# Download a file
gws drive files get --fileId <file-id> --alt media > output.pdf

# Delete a file
gws drive files delete --fileId <file-id>
```

### Gmail

```bash
# List messages
gws gmail users.messages list --userId me

# Search messages
gws gmail users.messages list --userId me --q "from:user@example.com subject:report"

# Get a message
gws gmail users.messages get --userId me --id <message-id>

# Send a message (draft and send)
gws gmail users.messages send --userId me --raw <base64-encoded-message>
```

### Google Calendar

```bash
# List calendars
gws calendar calendarList list

# List upcoming events
gws calendar events list --calendarId primary --timeMin "2026-03-10T00:00:00Z" --singleEvents true --orderBy startTime

# Create an event
gws calendar events insert --calendarId primary --summary "Team sync" --start '{"dateTime":"2026-03-11T10:00:00","timeZone":"Europe/Madrid"}' --end '{"dateTime":"2026-03-11T11:00:00","timeZone":"Europe/Madrid"}'

# Delete an event
gws calendar events delete --calendarId primary --eventId <event-id>
```

### Google Sheets

```bash
# Create a spreadsheet
gws sheets spreadsheets create --title "Monthly Report"

# Read cell values
gws sheets spreadsheets.values get --spreadsheetId <id> --range "Sheet1!A1:D10"

# Update cell values
gws sheets spreadsheets.values update --spreadsheetId <id> --range "Sheet1!A1" --valueInputOption USER_ENTERED --values '[["Header1","Header2"],["val1","val2"]]'
```

### Google Docs

```bash
# Get document content
gws docs documents get --documentId <doc-id>

# Create a document
gws docs documents create --title "Meeting Notes"
```

### Google Chat

```bash
# List spaces
gws chat spaces list

# Send a message
gws chat spaces.messages create --parent "spaces/<space-id>" --text "Hello from gws CLI"
```

## Output format

All responses are structured JSON. Pipe to `jq` for filtering:

```bash
# Get file names only
gws drive files list | jq '.files[].name'

# Count unread emails
gws gmail users.messages list --userId me --q "is:unread" | jq '.resultSizeEstimate'
```

## Useful flags

| Flag | Description |
|------|-------------|
| `--page-all` | Automatically paginate through all results |
| `--dry-run` | Preview the API call without executing |
| `--output json` | Force JSON output (default) |

## Safety rules

- **Destructive operations** (`delete`, `trash`, `permanently delete`) require user confirmation before executing.
- **Sending emails or messages** — always show the recipient, subject, and body to the user and ask for confirmation.
- **Modifying shared documents/spreadsheets** — confirm with the user before overwriting content.
- **Calendar events** — confirm attendees and time before creating/modifying events.

## Attribution

Based on [googleworkspace/cli](https://github.com/googleworkspace/cli).
