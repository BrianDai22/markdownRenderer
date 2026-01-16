# Implementation checklist

## Project + metadata

- `MarkdownRenderer.xcodeproj`: macOS app target, Sequoia deployment target
- `MarkdownRenderer/Info.plist`: `.md` document type (`public.markdown`, extension `md` only)

## Document-based app

- `MarkdownRenderer/MarkdownDocument.swift`: `FileDocument` read/write UTF-8 text
- `MarkdownRenderer/MarkdownRendererApp.swift`: `DocumentGroup` scene

## Tabs

- `MarkdownRenderer/AppDelegate.swift`: enable automatic window tabbing + in-tab-bar preference

## Editor

- `MarkdownRenderer/Editor/EditorTextView.swift`: `NSTextView` bridge (binding to document text)

## Preview

- `MarkdownRenderer/Preview/PreviewWebView.swift`: `WKWebView` wrapper + link handling
- `MarkdownRenderer/Preview/MarkdownHTMLRenderer.swift`: safe minimal Markdown→HTML (placeholder for GFM engine)

## Hybrid layout controls

- `MarkdownRenderer/LayoutCoordinator.swift`: global layout persisted to `UserDefaults`
- `MarkdownRenderer/DocumentSceneView.swift`: per-tab pin override + toolbar toggles
- `MarkdownRenderer/Commands/MarkdownRendererCommands.swift`: menu commands via focused actions

## Next hardening steps (post-scaffold)

- Replace placeholder renderer with GFM-accurate engine (`cmark-gfm`) + test fixtures
- Add file watcher + smart reload prompts
- Add editor syntax highlighting + list continuation + indent/outdent
- Add render debounce cancellation + perf safeguards for large files

