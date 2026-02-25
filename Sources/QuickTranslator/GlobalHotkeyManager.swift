import AppKit
import CoreGraphics
import OSLog

private let logger = Logger(subsystem: "com.emre.SuperTranslator", category: "Hotkey")

// The literal string value of kAXTrustedCheckOptionPrompt (avoids Swift 6 concurrency error).
private let axPromptKey = "AXTrustedCheckOptionPrompt"

@Observable
@MainActor
final class GlobalHotkeyManager {
    var isAccessibilityTrusted: Bool = false

    private let translationManager: TranslationManager
    private let toastPresenter = TranslationToastPresenter()
    private var lastControlCTime: Date?
    private var pollTimer: Timer?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(translationManager: TranslationManager) {
        self.translationManager = translationManager
        isAccessibilityTrusted = Self.isTrusted()
        print("[Hotkey] init — accessibility trusted: \(isAccessibilityTrusted)")

        if !isAccessibilityTrusted {
            print("[Hotkey] Prompting for Accessibility...")
            _ = Self.isTrusted(prompt: true)
        } else {
            print("[Hotkey] Accessibility OK — installing event tap...")
            installEventTap()
        }

        startPolling()
    }

    // MARK: - Accessibility

    @discardableResult
    private static func isTrusted(prompt: Bool = false) -> Bool {
        let opts: [String: Any] = [axPromptKey: prompt]
        return AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let trusted = Self.isTrusted()
                guard trusted != self.isAccessibilityTrusted else {
                    // If trusted and tap is gone, reinstall
                    if trusted && self.eventTap == nil {
                        self.installEventTap()
                    }
                    return
                }

                self.isAccessibilityTrusted = trusted
                if trusted {
                    logger.info("Accessibility trust granted.")
                    self.installEventTap()
                } else {
                    logger.warning("Accessibility trust revoked.")
                    self.removeEventTap()
                }
            }
        }
    }

    func cleanup() {
        pollTimer?.invalidate()
        pollTimer = nil
        removeEventTap()
    }

    // MARK: - CGEvent Tap (works with Accessibility, no Input Monitoring needed)

    private func installEventTap() {
        guard eventTap == nil else {
            logger.info("Event tap already installed.")
            return
        }

        logger.info("Installing CGEvent tap for Control+C ×2...")

        // We need a pointer to self for the C callback.
        // Use Unmanaged to pass it through the void* userInfo.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,       // We only listen, never modify events
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    // Re-enable the tap
                    if let tap = manager.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passRetained(event)
                }

                // Extract keycode and modifiers
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags

                // Log every key event for diagnostics (print, not logger, so it shows in terminal)
                print("[CGEvent] keyCode=\(keyCode) flags=\(flags.rawValue)")

                // keyCode 8 = 'C', check for Command (⌘+C double-tap to translate)
                if keyCode == 8
                    && flags.contains(.maskCommand)
                    && !flags.contains(.maskControl) {

                    let now = Date()
                    Task { @MainActor in
                        if let prev = manager.lastControlCTime, now.timeIntervalSince(prev) < 0.4 {
                            manager.lastControlCTime = nil
                            logger.info("Control+C ×2 detected → translating")
                            manager.triggerTranslation()
                        } else {
                            manager.lastControlCTime = now
                            logger.info("Control+C detected (first tap)")
                        }
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        ) else {
            logger.error("CGEvent.tapCreate returned nil — Accessibility permission not granted!")
            return
        }

        self.eventTap = tap
        print("[Hotkey] CGEvent.tapCreate succeeded — tap is non-nil")

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[Hotkey] Event tap enabled and added to main run loop")

        // Verify the tap is actually enabled
        let enabled = CGEvent.tapIsEnabled(tap: tap)
        print("[Hotkey] Tap enabled check: \(enabled)")
    }

    private func removeEventTap() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        logger.info("CGEvent tap removed.")
    }

    // MARK: - Translation

    private func triggerTranslation() {
        translationManager.translatedText = ""
        translationManager.isTranslating = true
        toastPresenter.show(manager: translationManager)
        translationManager.translateCopiedText()
    }

    func retrySetup() {
        if !isAccessibilityTrusted {
            Self.isTrusted(prompt: true)
        }
    }
}
