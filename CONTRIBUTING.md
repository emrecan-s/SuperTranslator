# Contributing to SuperTranslator

Thank you for your interest! Contributions are welcome via GitHub Issues and Pull Requests.

## How to Build Locally

```bash
git clone https://github.com/YOUR_USERNAME/SuperTranslator.git
cd SuperTranslator

# One-time: create the self-signed code-signing certificate
./setup_cert.sh

# Allow codesign to use the cert without prompting
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" ~/Library/Keychains/login.keychain-db

# Build + run
./build_app.sh && open SuperTranslator.app
```

## Pull Request Guidelines

- Open an **issue first** for major changes to discuss the approach before coding
- Keep PRs focused — one feature or fix per PR
- Code style: follow Swift API Design Guidelines; use `OSLog` (not `print`) for logging
- **Never commit API keys** — the app reads them from `UserDefaults` at runtime
- **Never commit `SuperTranslator.app`** — it's in `.gitignore` for a reason

## Important: API Key Safety

- The `apiKey` is stored in `UserDefaults` — it is **never** in source code
- If you accidentally add a key to source, rotate it immediately at [aistudio.google.com](https://aistudio.google.com/app/apikey)

## Reporting Bugs

Please include:
- macOS version
- Steps to reproduce
- Relevant output from: `log stream --level debug --predicate 'subsystem == "com.emre.SuperTranslator"'`
