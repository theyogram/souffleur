import AppKit
import SwiftUI

struct SettingsView: View {
    private let inputDevices: () -> [(uid: String, name: String)]
    private let locales: () async -> [(identifier: String, name: String)]

    @State private var availableDevices: [(uid: String, name: String)] = []
    @State private var availableLocales: [(identifier: String, name: String)] = []

    @AppStorage(SettingsKeys.fontFamily) private var fontFamily = PrompterFontFamily.rounded.rawValue
    @AppStorage(SettingsKeys.fontSize) private var fontSize = 32.0
    @AppStorage(SettingsKeys.lineSpacing) private var lineSpacing = 1.0
    @AppStorage(SettingsKeys.alignment) private var alignment = PrompterAlignment.left.rawValue
    @AppStorage(SettingsKeys.backgroundOpacity) private var backgroundOpacity = 0.35
    @AppStorage(SettingsKeys.dimSpokenText) private var dimSpokenText = true
    @AppStorage(SettingsKeys.readingLine) private var readingLine = 0.20
    @AppStorage(SettingsKeys.mirror) private var mirror = false
    @AppStorage(SettingsKeys.scrollMode) private var scrollMode = ScrollMode.voice.rawValue
    @AppStorage(SettingsKeys.constantSpeed) private var constantSpeed = 40.0
    @AppStorage(SettingsKeys.soundThresholdDb) private var soundThresholdDb = -45.0
    @AppStorage(SettingsKeys.recognitionLocale) private var recognitionLocale = ""
    @AppStorage(SettingsKeys.audioInputUID) private var audioInputUID = ""
    @AppStorage(SettingsKeys.allowBackward) private var allowBackward = false
    @AppStorage(SettingsKeys.removeEmptyLines) private var removeEmptyLines = false

    init(inputDevices: @escaping () -> [(uid: String, name: String)], locales: @escaping () async -> [(identifier: String, name: String)]) {
        self.inputDevices = inputDevices
        self.locales = locales
    }

    var body: some View {
        TabView {
            generalSettings
                .tabItem { Label("Général", systemImage: "textformat.size") }
            scrollingSettings
                .tabItem { Label("Défilement", systemImage: "scroll") }
            scriptSettings
                .tabItem { Label("Scripts", systemImage: "text.book.closed") }
        }
        .frame(width: 520, height: 520)
        .task {
            availableDevices = inputDevices()
            availableLocales = await locales()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            availableDevices = inputDevices()
        }
    }

    private var generalSettings: some View {
        Form {
            Section("Texte") {
                Picker("Police", selection: $fontFamily) {
                    Text("Système").tag(PrompterFontFamily.system.rawValue)
                    Text("Arrondie").tag(PrompterFontFamily.rounded.rawValue)
                    Text("Serif").tag(PrompterFontFamily.serif.rawValue)
                    Text("Mono").tag(PrompterFontFamily.mono.rawValue)
                }
                LabeledContent("Taille") {
                    HStack {
                        Slider(value: $fontSize, in: 16...120, step: 1)
                        Text("\(Int(fontSize)) pt").monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                }
                Text("Raccourcis dans le prompteur : ⌘+ et ⌘−, ⌘0 pour réinitialiser.")
                    .font(.caption).foregroundStyle(.secondary)
                LabeledContent("Interligne") {
                    HStack {
                        Slider(value: $lineSpacing, in: 0.8...2.0, step: 0.05)
                        Text("\(Int((lineSpacing * 100).rounded())) %")
                            .monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                }
                Picker("Alignement", selection: $alignment) {
                    Text("Gauche").tag(PrompterAlignment.left.rawValue)
                    Text("Centre").tag(PrompterAlignment.center.rawValue)
                    Text("Droite").tag(PrompterAlignment.right.rawValue)
                }
                .pickerStyle(.segmented)
            }
            Section("Apparence") {
                LabeledContent("Opacité du fond") {
                    HStack {
                        Slider(value: $backgroundOpacity, in: 0...0.95, step: 0.01)
                        Text("\(Int((backgroundOpacity * 100).rounded())) %")
                            .monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                }
                Toggle("Estomper le texte lu", isOn: $dimSpokenText)
                LabeledContent("Position de la zone de lecture") {
                    HStack {
                        Slider(value: $readingLine, in: 0...0.5, step: 0.01)
                        Text("\(Int((readingLine * 100).rounded())) %")
                            .monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                }
                Toggle("Mode miroir", isOn: $mirror)
            }
        }
        .formStyle(.grouped)
    }

    private var scrollingSettings: some View {
        Form {
            Section("Mode") {
                Picker("Défilement", selection: $scrollMode) {
                    Text("Voix").tag(ScrollMode.voice.rawValue)
                    Text("Son").tag(ScrollMode.sound.rawValue)
                    Text("Constant").tag(ScrollMode.constant.rawValue)
                }
                .pickerStyle(.segmented)
                Text(modeDescription).font(.caption).foregroundStyle(.secondary)
                if scrollMode == ScrollMode.constant.rawValue || scrollMode == ScrollMode.sound.rawValue {
                    LabeledContent("Vitesse") {
                        HStack {
                            Slider(value: $constantSpeed, in: 10...200, step: 1)
                            Text("\(Int(constantSpeed)) pt/s").monospacedDigit().frame(width: 72, alignment: .trailing)
                        }
                    }
                }
                if scrollMode == ScrollMode.sound.rawValue {
                    LabeledContent("Sensibilité") {
                        HStack {
                            Slider(value: $soundThresholdDb, in: -70 ... -20, step: 1)
                            Text("\(Int(soundThresholdDb)) dB").monospacedDigit().frame(width: 72, alignment: .trailing)
                        }
                    }
                }
            }
            Section("Voix et micro") {
                Picker("Langue", selection: $recognitionLocale) {
                    Text("Automatique").tag("")
                    ForEach(availableLocales, id: \.identifier) { locale in
                        Text(locale.name).tag(locale.identifier)
                    }
                }
                Toggle("Autoriser le retour en arrière", isOn: $allowBackward)
                Picker("Entrée audio", selection: $audioInputUID) {
                    Text("Par défaut du système").tag("")
                    ForEach(availableDevices, id: \.uid) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                Text("Les AirPods peuvent ajouter de la latence.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var scriptSettings: some View {
        Form {
            Section("Texte du prompteur") {
                Toggle("Supprimer les lignes vides", isOn: $removeEmptyLines)
                Text("Le texte enregistré reste inchangé. Les lignes vides sont retirées seulement à l'ouverture dans le prompteur.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var modeDescription: String {
        switch scrollMode {
        case ScrollMode.sound.rawValue:
            return "Le texte défile tant que le micro capte du son."
        case ScrollMode.constant.rawValue:
            return "Le texte défile à vitesse fixe."
        default:
            return "Le texte suit les mots que tu prononces."
        }
    }
}
