import SwiftUI
import AppKit
import OSLog

private let logger = Logger(subsystem: "com.emre.SuperTranslator", category: "App")

@MainActor
@Observable
class AppDelegate: NSObject, NSApplicationDelegate {
    var translationManager = TranslationManager()
    var hotkeyManager: GlobalHotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("App launched")
        if hotkeyManager == nil {
            hotkeyManager = GlobalHotkeyManager(translationManager: translationManager)
        }
    }
}

@main
struct QuickTranslatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("SuperTranslator", systemImage: "character.bubble.fill") {
            ContentView(manager: appDelegate.translationManager, hotkeyManager: appDelegate.hotkeyManager)
        }
        .menuBarExtraStyle(.window)
    }
}
