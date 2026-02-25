import SwiftUI
import AppKit
import Observation

struct TranslationToastView: View {
    @Bindable var manager: TranslationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "character.bubble.fill")
                    .foregroundStyle(.blue)
                Text("QuickTranslator")
                    .font(.headline)
                Spacer(minLength: 8)
            }

            if manager.isTranslating {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Translating…")
                        .foregroundStyle(.secondary)
                }
            } else {
                if manager.translatedText.isEmpty {
                    Text("No translation.")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        Text(manager.translatedText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                    }
                    .frame(minHeight: 80, maxHeight: 200)
                }
            }
        }
        .padding(12)
        .frame(width: 360)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(radius: 12)
    }
}

final class TranslationToastPresenter {
    private var panel: NSPanel?
    private var autoCloseTask: Task<Void, Never>?

    @MainActor func show(manager: TranslationManager, autoCloseAfter seconds: TimeInterval = 6) {
        print("DEBUG: TranslationToastPresenter.show() called")
        if panel == nil {
            print("DEBUG: Creating new toast panel")
            let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 160),
                                styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                                backing: .buffered,
                                defer: false)
            panel.isFloatingPanel = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isMovableByWindowBackground = true
            
            let content = NSHostingView(rootView: TranslationToastView(manager: manager))
            content.frame = panel.contentView?.bounds ?? .zero
            content.autoresizingMask = [.width, .height]
            panel.contentView = content
            self.panel = panel
        }

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let x = visible.maxX - 400
            let y = visible.maxY - 220
            print("DEBUG: Setting toast position to (\(x), \(y))")
            panel?.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            print("DEBUG ERROR: NSScreen.main is nil, using default position")
            panel?.center()
        }

        print("DEBUG: Making toast panel visible")
        panel?.makeKeyAndOrderFront(nil)

        autoCloseTask?.cancel()
        autoCloseTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            } catch { }
            await MainActor.run {
                if manager.isTranslating == false {
                    self?.panel?.orderOut(nil)
                }
            }
        }
    }

    @MainActor func close() {
        autoCloseTask?.cancel()
        panel?.orderOut(nil)
    }
}

