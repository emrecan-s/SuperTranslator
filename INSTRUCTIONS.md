# Instructions

You are a 10x senior macOS developer with expert knowledge of Swift, SwiftUI, AppKit, and all Core frameworks.

## Project: SuperTranslator

A macOS menu bar app that translates copied text via the Gemini API using the `⌘C ×2` global hotkey.

See [README.md](README.md) for full project overview and [CONTRIBUTING.md](CONTRIBUTING.md) for build instructions.

## Architecture

- **`GlobalHotkeyManager`** — `CGEvent.tapCreate` session tap; detects `⌘C` within 0.4s window
- **`TranslationManager`** — Gemini REST API calls; API key in `UserDefaults`
- **`TranslationToastPresenter`** — Floating `NSPanel` toast overlay
- **`ContentView`/`SettingsView`** — SwiftUI menu bar popover UI

## Code Standards

- Swift 6 strict concurrency — all actors/isolation must be explicit
- Use `OSLog` (`Logger`) for all logging — no `print()` statements
- API key must **never** appear in source code — always read from `UserDefaults`
- No binary artifacts (`.app`, `.o`, `.build/`) should be committed
- All changes must build cleanly with `./build_app.sh` before committing

## Key Technical Details

### Code Signing
The app must be signed with the `SuperTranslatorDev` self-signed certificate (not ad-hoc) so that Accessibility (TCC) permissions survive rebuilds. See `build_app.sh`.

### Hotkey Detection
`NSEvent.addGlobalMonitorForEvents` does NOT work on Sequoia without Input Monitoring permission (which shows no system prompt). Use `CGEvent.tapCreate` with `.listenOnly` instead — this works with just Accessibility permission.

### TCC / Accessibility
`AXIsProcessTrustedWithOptions` is polled every 2 seconds in `GlobalHotkeyManager`. If trust is granted, the event tap is installed. If revoked, it's removed. Show `accessibilityWarning` banner in `ContentView` when not trusted.

## Development Workflow

```bash
# Build + sign + launch
./build_app.sh && open SuperTranslator.app

# Check logs
log stream --level debug --predicate 'subsystem == "com.emre.SuperTranslator"'
```
