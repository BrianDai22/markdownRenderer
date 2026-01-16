# MarkdownRenderer

macOS Sequoia-only Markdown editor with live “pretty” preview.

## Build

- Open `MarkdownRenderer.xcodeproj` in Xcode 26.2
- Build/run the `MarkdownRenderer` target
- Optional gate: `Scripts/verify.sh`

## Finder integration

The app declares support for `.md` files. To make it the default:

- Finder → select a `.md` → Get Info → Open with → MarkdownRenderer → Change All…

## Features (current)

- Native tabs (one doc per tab)
- Sidebar: recents + open folder + file list + outline
- Live preview (GFM-ish) via bundled JS renderer (no network)
