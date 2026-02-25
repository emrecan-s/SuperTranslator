import SwiftUI

struct ContentView: View {
    @Bindable var manager: TranslationManager
    var hotkeyManager: GlobalHotkeyManager?
    
    var body: some View {
        VStack(spacing: 15) {
            header
            
            if let hotkeyManager, !hotkeyManager.isAccessibilityTrusted {
                accessibilityWarning(hotkeyManager)
            }
            
            if manager.isTranslating {
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
        .frame(width: 400, height: 450)
    }
    
    private var header: some View {
        HStack {
            Image(systemName: "character.bubble.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            Text("SuperTranslator")
                .font(.headline)
            Spacer()
        }
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
            Button(action: {
                manager.translateCopiedText()
            }) {
                Label("Translate Clipboard", systemImage: "doc.on.clipboard")
            }
            .buttonStyle(.borderedProminent)
            .disabled(manager.isTranslating)
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
    }

    private func accessibilityWarning(_ hotkeyManager: GlobalHotkeyManager) -> some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Accessibility Permission Needed")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            
            Text("The global hotkey require Accessibility permissions to work.")
                .font(.caption)
                .multilineTextAlignment(.center)
            
            HStack {
                Button("Open Settings") {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.bordered)
                
                Button("Retry") {
                    hotkeyManager.retrySetup()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
