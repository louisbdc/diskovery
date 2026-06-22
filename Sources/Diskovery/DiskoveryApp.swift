import SwiftUI
import AppKit

/// Délégué d'application : un exécutable SPM brut démarre comme un processus
/// `BackgroundOnly` sans icône dans le Dock, sans barre de menus et sans fenêtre
/// au premier plan. On force ici la politique d'activation `.regular` pour que
/// l'app se comporte comme une application interactive normale.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct DiskoveryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Diskovery") {
            ContentView()
                .frame(minWidth: 700, minHeight: 450)
        }
        .defaultSize(width: 900, height: 600)
        .windowResizability(.contentMinSize)
    }
}
