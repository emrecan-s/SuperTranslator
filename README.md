<p align="center">
  <img src="https://img.shields.io/badge/macOS-15.0%2B-blue" alt="macOS 15+"/>
  <img src="https://img.shields.io/badge/Swift-6.0-orange" alt="Swift 6"/>
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License"/>
</p>

# SuperTranslator

A lightweight macOS menu bar app that instantly translates any copied text using the Gemini AI API.

**Press ⌘C twice quickly** in any app → a floating toast pops up with the English translation.

---

## Features

- 🔑 **Double ⌘C hotkey** — works in any app, no need to switch windows
- 💬 **Floating toast** — translation appears as a non-intrusive panel, auto-closes after 5s
- 🧠 **Gemini AI** — uses `gemini-2.5-flash-lite` (auto-resolved to latest available)
- 🔒 **Privacy-first** — API key stored in UserDefaults, never hardcoded or sent anywhere else
- 📋 **Menu bar app** — no Dock icon, no ⌘+Tab entry
- ✅ **Persistent permissions** — thanks to self-signed certificate signing, Accessibility permission survives all future rebuilds

---

## Installation

### Prerequisites

- macOS 15 (Sequoia) or later
- Xcode Command Line Tools: `xcode-select --install`
- A free [Gemini API key](https://aistudio.google.com/app/apikey)

### Build from Source

```bash
git clone https://github.com/YOUR_USERNAME/SuperTranslator.git
cd SuperTranslator

# One-time: create the self-signed code-signing certificate
./setup_cert.sh

# Build and open
./build_app.sh && open SuperTranslator.app
```

### First Run

1. Click the **💬 icon** in your menu bar
2. Click the **⚙️ gear icon** → Settings
3. Paste your Gemini API key and click **Save**
4. Grant **Accessibility permission** when prompted (required for the global hotkey)

> The Accessibility permission only needs to be granted once. It persists across all future rebuilds because the app is signed with a self-signed certificate.

---

## Code Signing (Why It's Needed)

macOS Sequoia stores Accessibility (TCC) permissions by `cdhash`. Ad-hoc signed apps get a new `cdhash` on every rebuild, so permissions are lost. Signing with a self-signed certificate means TCC tracks by the **certificate leaf hash** instead — which is stable across rebuilds.

See [`setup_cert.sh`](setup_cert.sh) for the one-time setup.

---

## Configuration

| Setting | Where |
|---|---|
| API Key | Menu bar icon → ⚙️ Settings |
| Hotkey | `GlobalHotkeyManager.swift` (default: ⌘C ×2 within 0.4s) |
| Model | `TranslationManager.swift` (default: auto-resolves `gemini-2.5-flash-lite`) |

---

## Project Structure

```
Sources/QuickTranslator/
├── QuickTranslatorApp.swift       # App entry point, AppDelegate, MenuBarExtra
├── ContentView.swift              # Menu bar popover + settings UI
├── GlobalHotkeyManager.swift      # ⌘C×2 detection via CGEvent tap
├── TranslationManager.swift       # Gemini REST API + state
├── TranslationToastView.swift     # Floating NSPanel toast
├── App-Info.plist                 # Bundle ID, LSUIElement=YES
└── App-Entitlements.entitlements
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

[MIT](LICENSE) © 2026 Emre
