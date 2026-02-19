# DesktopDeclutter for macOS

A SwiftUI macOS app for reviewing and organizing messy folders quickly with swipe actions, bulk operations, smart grouping suggestions, and cloud/local move flows.

![Desktop Declutter Demo](desktopdeclutter.gif)

## What is new in this version

The app has moved well beyond "Desktop-only swipe to trash/keep":

- Scan any folder (not just Desktop) via folder picker
- Navigate into subfolders with breadcrumbs and back navigation
- Two review modes: Swipe/Card mode for one-by-one decisions, and Gallery mode for multi-select bulk actions
- Move files to local folders or cloud destinations (iCloud / Google Drive / CloudStorage)
- Session history timeline with undo/redo logs
- Group review for related files with smart bulk actions
- Stacked files and binned-file review panels
- File type filtering and improved toolbar/action dock workflow
- Menu bar extra for quick window access

## Features

### Review workflows

- Swipe/Card review with `Right Arrow` (keep), `Left Arrow` (bin), `S` (stack), and `F` (next)
- Gallery review with multi-select and bulk keep/bin/cloud/move actions

### Smart suggestions

Suggestions are detected per file and can launch grouped review:

- Duplicates (same file name and size)
- Similar naming groups (CleanShot/screenshot/versioned/dated patterns)
- Old files (over 1 year old, higher signal for 2+ years)
- Large files (100MB+; higher priority at 500MB+)
- Same-session files (created within a 5-minute window)
- Temporary file patterns (`tmp`, `cache`, `log`, `bak`, `old`, etc.)

### Group review and smart actions

- Open grouped files from suggestion badges
- Preview the group with Quick Look
- Use generated smart action cards (for supported suggestion types), including: keep newest and bin the rest (duplicates), keep newest N files (similar-name groups), and bin files older than 1 week (similar-name groups)

### Organization and movement

- Move to any local destination folder
- Move to configured cloud destinations
- Cloud destination management in Settings: add/remove destinations and set the active one
- Provider detection for iCloud Drive / Google Drive / CloudStorage
- Files moved to cloud are organized under `DesktopDeclutter/<source-folder>/...`

### Session controls

- Undo/redo with history stack
- Session history popover with action timeline
- Reset session (undo all actions)
- Trash modes: immediate trash or delayed trash review (binned queue)
- Stack queue for deferred review

### UI and macOS integration

- Material/blur desktop-native UI
- Quick Look preview integration (with Finder fallback)
- Sidebar with file list, current selection, and inline undo
- Welcome overlay animation on launch/refocus
- Menu bar item with Show Window and Quit actions

## Keyboard shortcuts

| Key | Action |
|---|---|
| `←` | Bin current file |
| `→` | Keep current file |
| `S` | Stack current file |
| `F` | Go to next file |
| `Space` | Preview current file (Quick Look) |
| `C` | Move current file to cloud |
| `M` | Move current file to folder |
| `Return` | Enter folder (when current item is a folder) |
| `⌘Z` | Undo |
| `⌘⇧Z` | Redo |
| `Esc` | Close Quick Look panel |
| `⌘W` | Show app window (menu bar action) |
| `⌘Q` | Quit app |

## How to use

1. Launch the app and choose a folder to scan.
2. Review items in Swipe mode or switch to Gallery mode.
3. Use suggestion badges to review related files in groups.
4. Move, keep, stack, or bin files.
5. Review stacked/binned queues before final trashing (if delayed binning is enabled).

## Installation

### Requirements

- macOS 13.0+ (Ventura or newer)
- Swift 5.9+
- Xcode Command Line Tools

### Build and run

```bash
git clone https://github.com/yourusername/DesktopDeclutter.git
cd DesktopDeclutter
swift build
swift run
```

## Settings

- `Trash Immediately`: bin actions go directly to Trash
- `Change Scan Folder...`: choose a different folder to review
- `Cloud Destinations`: connect cloud folders for cloud moves

## Technical notes

- Built with SwiftUI + AppKit integrations
- Uses `QuickLookUI` and `QuickLookThumbnailing`
- Uses security-scoped bookmarks for user-chosen cloud folders
- No third-party package dependencies

## Current limitations

- Duplicate detection is heuristic-based (name + size), not content hashing
- Suggestion matching is intentionally bounded for responsiveness on large folders
- As with any file-management app, review actions carefully before bulk bin/move operations

## Contributing

Issues and pull requests are welcome.

## License

MIT License. See `LICENSE.md`.

You can use, modify, and distribute this project freely under the MIT terms.
