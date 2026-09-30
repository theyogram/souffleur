// Point d'entrée. Squelette M0 : sera câblé par le worker d'intégration.
import SwiftUI

@main
struct SouffleurApp: App {
    init() { SettingsKeys.register() }

    var body: some Scene {
        MenuBarExtra("Souffleur", systemImage: "text.viewfinder") {
            Button("Quitter Souffleur") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        Settings { Text("Réglages").padding() }
    }
}
