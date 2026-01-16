# Spec: MarkdownRenderer (macOS)

## Product

- macOS-only Markdown editor + live preview
- Primary loop: open `.md` → edit → instant render → save
- Deployment target: macOS Sequoia (15.x)

## Core UX (v1)

- Single window; native tab bar; each tab = one document
- Two-pane split: Editor (left) + Preview (right)
- Drag/drop `.md` onto window to open
- Cmd+O open file; multi-file open → tabs
- Close tab prompts if dirty

## “Pretty” preview

- Typography-first “article” layout
- Light/dark themes (CSS tokens)
- Code blocks styled + highlighted (Prism)

## File association

- App declares `.md` document type (only)
- Double-click `.md` opens in app
- macOS default handler still user-controlled (“Open with” → “Change All…”)

## Layout model (hybrid)

- Global defaults: preview visible, split ratio, scroll-sync
- Per-tab override opt-in via “Pin layout to tab”
- If tab not pinned: layout edits update global defaults
- If tab pinned: layout edits only affect that tab

## Deferred (v1.1+)

- Mermaid rendering
- LaTeX/KaTeX math
- Workspace folder tree indexing optimizations
- Robust cursor↔preview source mapping
- Full-text workspace search
