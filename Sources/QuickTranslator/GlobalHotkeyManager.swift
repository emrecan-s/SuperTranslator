import AppKit
import CoreGraphics
import OSLog

private let logger = Logger(subsystem: "com.emre.SuperTranslator", category: "Hotkey")

// Store kAXTrustedCheckOptionPrompt as a literal to avoid Swift 6 C-global concurrency warnings.
private let axPromptKey = "AXTrustedCheckOptionPrompt"

@Observable
@MainActor
final class GlobalHotkeyManager {
    var isAccessibilityTrusted: Bool = false

    private let translationManager: TranslationManager
    private let toastPresenter = TranslationToastPresenter()
    private var lastCommandCTime: Date?
    private var pollTimer: Timer?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(translationManager: TranslationManager) {
        self.translationManager = translationManager
        isAccessibilityTrusted = Self.isTrusted()

        if !isAccessibilityTrusted {
            _ = Self.isTrusted(prompt: true)
        } else {
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

    /// Polls every 2 seconds to detect permission grants or revocations.
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let trusted = Self.isTrusted()
                guard trusted != self.isAccessibilityTrusted else {
                    if trusted && self.eventTap == nil { self.installEventTap() }
                    return
                }
                self.isAccessibilityTrusted = trusted
                if trusted {
                    logger.info("Accessibility trust granted — installing event tap")
                    self.installEventTap()
                } else {
                    logger.warning("Accessibility trust revoked — removing event tap")
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

    // MARK: - CGEvent Tap

    /// Installs a CGEvent session tap to intercept ⌘C double-tap globally.
    /// CGEvent taps work with just Accessibility permission (no Input Monitoring needed).
    private func installEventTap() {
        guard eventTap == nil else { return }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { (_, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()

                // Re-enable the tap if macOS disables it (e.g. after a timeout)
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = manager.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                    return Unmanaged.passRetained(event)
                }

                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags

                // Detect ⌘C (keyCode 8 = C, maskCommand set, maskControl NOT set)
                guard keyCode == 8,
                      flags.contains(.maskCommand),
                      !flags.contains(.maskControl) else {
                    return Unmanaged.passRetained(event)
                }

                let now = Date()
                Task { @MainActor in
                    if let prev = manager.lastCommandCTime, now.timeIntervalSince(prev) < 0.4 {
                        manager.lastCommandCTime = nil
                        logger.info("⌘C ×2 detected — triggering translation")
                        manager.triggerTranslation()
                    } else {
                        manager.lastCommandCTime = now
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: selfPtr
        ) else {
            logger.error("CGEvent.tapCreate returned nil — Accessibility permission not granted")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logger.info("CGEvent tap installed and enabled")
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
        logger.info("CGEvent tap removed")
    }

    // MARK: - Translation

    private func triggerTranslation() {
        translationManager.translatedText = ""
        translationManager.isTranslating = true
        toastPresenter.show(manager: translationManager)
        translationManager.translateCopiedText()
    }

    func retrySetup() {
        if !isAccessibilityTrusted { Self.isTrusted(prompt: true) }
    }
}
