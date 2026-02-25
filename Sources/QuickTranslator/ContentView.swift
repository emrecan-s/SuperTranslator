import SwiftUI

struct ContentView: View {
    @Bindable var manager: TranslationManager
    var hotkeyManager: GlobalHotkeyManager?
    @State private var showingSettings = false

    var body: some View {
        if showingSettings {
            SettingsView(manager: manager, showingSettings: $showingSettings)
        } else {
            mainView
        }
    }

    private var mainView: some View {
        VStack(spacing: 15) {
            header

            if let hotkeyManager, !hotkeyManager.isAccessibilityTrusted {
                accessibilityWarning(hotkeyManager)
            }

            if !manager.hasApiKey {
                apiKeyPrompt
            } else if manager.isTranslating {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .padding()
            } else {
                translationContent
            }

            Spacer()
            controls
        }
        .padding()
        .frame(width: 400, height: 500)
    }

    private var header: some View {
        HStack {
            Image(systemName: "character.bubble.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            Text("SuperTranslator")
                .font(.headline)
            Spacer()
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gear")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    private var apiKeyPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Gemini API Key Required")
                .font(.headline)
            Text("Add your free Gemini API key to get started.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") { showingSettings = true }
                .buttonStyle(.borderedProminent)
            Link("Get a free API key →", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.25)))
    }

    private var translationContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !manager.sourceText.isEmpty {
                    GroupBox(label: Text("Original Text").font(.caption).foregroundColor(.secondary)) {
                        Text(manager.sourceText)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                }
                if !manager.translatedText.isEmpty {
                    GroupBox(label: Text("Translated (English US)").font(.caption).foregroundColor(.secondary)) {
                        Text(manager.translatedText)
                            .font(.body)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                } else if !manager.isTranslating && !manager.sourceText.isEmpty {
                    Text("Ready to translate...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var controls: some View {
        HStack {
            Button(action: { manager.translateCopiedText() }) {
                Label("Translate Clipboard", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.borderedProminent)
            .disabled(manager.isTranslating || !manager.hasApiKey)

            Spacer()

            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
        }
    }

    private func accessibilityWarning(_ hotkeyManager: GlobalHotkeyManager) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                Text("Accessibility Permission Needed").font(.subheadline).fontWeight(.bold)
            }
            Text("The global hotkey requires Accessibility permissions to work.")
                .font(.caption).multilineTextAlignment(.center)
            HStack {
                Button("Open Settings") {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.bordered)
                Button("Retry") { hotkeyManager.retrySetup() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Settings (inline, no sheet — sheets don't dismiss reliably in MenuBarExtra)

struct SettingsView: View {
    @Bindable var manager: TranslationManager
    @Binding var showingSettings: Bool
    @State private var apiKeyInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with back button
            HStack {
                Button {
                    showingSettings = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Spacer()

                Text("Settings")
                    .font(.headline)

                Spacer()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("Gemini API Key", systemImage: "key.fill")
                    .font(.headline)

                SecureField("Paste your API key here", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { saveAndDismiss() }

                Link("Get a free key at aistudio.google.com →",
                     destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            Spacer()

            HStack {
                Button("Cancel") { showingSettings = false }
                    .buttonStyle(.plain)
                Spacer()
                Button("Save") { saveAndDismiss() }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400, height: 220)
        .onAppear {
            apiKeyInput = manager.apiKey
        }
    }

    private func saveAndDismiss() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        manager.apiKey = trimmed
        showingSettings = false
    }
}
