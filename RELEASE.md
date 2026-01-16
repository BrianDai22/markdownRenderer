# Release checklist (macOS)

## Preflight

- `Scripts/verify.sh`
- Confirm deployment target is macOS Sequoia (15.x)
- Confirm `.md` document type registration still present in `MarkdownRenderer/Info.plist`

## Codesign + notarize (manual)

- Archive in Xcode
- Distribute for Developer ID
- Notarize (Xcode Organizer)
- Staple ticket

