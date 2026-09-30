import AppKit
import SwiftUI

@MainActor
final class SouffleurAppDelegate: NSObject, NSApplicationDelegate {
    let playback = PlaybackController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-speechSmokeTest") {
            Task {
                await SpeechSmokeTest.run(seconds: 20, deviceUID: nil)
                NSApp.terminate(nil)
            }
        } else if arguments.contains("-prompterDemo") {
            _ = PrompterDemo.show()
        } else {
            playback.launch()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        playback.terminate()
    }
}

@main
struct SouffleurApp: App {
    @NSApplicationDelegateAdaptor(SouffleurAppDelegate.self) private var delegate
    @Environment(\.openWindow) private var openWindow

    init() { SettingsKeys.register() }

    var body: some Scene {
        let _ = registerLibraryOpener()
        MenuBarExtra("Souffleur", systemImage: delegate.playback.state.isRunning ? "waveform" : "text.viewfinder") {
            SouffleurMenu(playback: delegate.playback)
        }
        .menuBarExtraStyle(.menu)

        Window("Scripts", id: "library") {
            LibraryScene(playback: delegate.playback)
        }
        .defaultSize(width: 760, height: 540)

        Settings {
            SettingsView(inputDevices: {
                AudioDevices.inputDevices().map { (uid: $0.id, name: $0.name) }
            }, locales: {
                await LocaleResolver.supportedLocales().map {
                    (identifier: $0.identifier, name: LocaleResolver.displayName(for: $0))
                }
            })
        }
    }

    private func registerLibraryOpener() {
        delegate.playback.onOpenLibrary = {
            openWindow(id: "library")
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

private struct SouffleurMenu: View {
    @Bindable var playback: PlaybackController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Afficher le prompteur") { playback.prompter.show() }
            .keyboardShortcut("1", modifiers: .command)
        Button("Lecture / Pause") { playback.playPause() }
            .keyboardShortcut(.space, modifiers: [])
        Button("Recommencer") { playback.restart() }
        Divider()
        Menu("Mode") {
            modeButton("Voix", .voice)
            modeButton("Constant", .constant)
            modeButton("Son", .sound)
        }
        Menu("Taille du texte") {
            Button("−") { stepFont(-1) }
            Button("+") { stepFont(1) }
            Button("Réinitialiser") { stepFont(0) }
        }
        Menu("Entrée audio") {
            Button("Par défaut du système") { UserDefaults.standard.set("", forKey: SettingsKeys.audioInputUID) }
            ForEach(AudioDevices.inputDevices()) { device in
                Button(device.name) { UserDefaults.standard.set(device.id, forKey: SettingsKeys.audioInputUID) }
            }
        }
        Divider()
        Button("Scripts…") { showLibrary() }
            .keyboardShortcut("e", modifiers: .command)
        SettingsLink { Text("Réglages…") }
            .keyboardShortcut(",", modifiers: .command)
        Button("Quitter Souffleur") { NSApp.terminate(nil) }
            .keyboardShortcut("q", modifiers: .command)
    }

    private func modeButton(_ label: String, _ mode: ScrollMode) -> some View {
        let selected = (UserDefaults.standard.string(forKey: SettingsKeys.scrollMode) ?? "voice") == mode.rawValue
        return Button((selected ? "✓ " : "") + label) {
            UserDefaults.standard.set(mode.rawValue, forKey: SettingsKeys.scrollMode)
        }
    }

    private func stepFont(_ step: Int) {
        let current = UserDefaults.standard.double(forKey: SettingsKeys.fontSize)
        UserDefaults.standard.set(step == 0 ? 32 : min(120, max(16, current + Double(step) * 2)), forKey: SettingsKeys.fontSize)
    }

    private func showLibrary() {
        playback.selectedScriptID = playback.currentScriptID
        openWindow(id: "library")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct LibraryScene: View {
    @Bindable var playback: PlaybackController

    var body: some View {
        LibraryView(store: playback.store, selection: $playback.selectedScriptID) { id in
            playback.openScript(id: id)
        }
    }
}
