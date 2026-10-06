// Clés UserDefaults et valeurs par défaut. PRD §7.7. FIGÉ : partagé par tous les modules.
import Foundation

enum SettingsKeys {
    static let fontFamily = "fontFamily"                // PrompterFontFamily.rawValue
    static let fontSize = "fontSize"                    // Double 16…120
    static let lineSpacing = "lineSpacing"              // Double 0.8…2.0
    static let alignment = "alignment"                  // PrompterAlignment.rawValue
    static let backgroundOpacity = "backgroundOpacity"  // Double 0…0.95
    static let dimSpokenText = "dimSpokenText"          // Bool
    static let readingLine = "readingLine"              // Double 0…0.5
    static let mirror = "mirror"                        // Bool
    static let scrollMode = "scrollMode"                // ScrollMode.rawValue
    static let constantSpeed = "constantSpeed"          // Double 10…200 pt/s
    static let soundThresholdDb = "soundThresholdDb"    // Double −70…−20
    static let recognitionLocale = "recognitionLocale"  // String identifier, "" = auto
    static let audioInputUID = "audioInputUID"          // String UID CoreAudio, "" = défaut système
    static let allowBackward = "allowBackward"          // Bool
    static let removeEmptyLines = "removeEmptyLines"    // Bool
    static let lastScriptID = "lastScriptID"            // String UUID

    static let defaults: [String: Any] = [
        fontFamily: PrompterFontFamily.rounded.rawValue,
        fontSize: 32.0,
        lineSpacing: 1.0,
        alignment: PrompterAlignment.left.rawValue,
        backgroundOpacity: 0.35,
        dimSpokenText: true,
        readingLine: 0.20,
        mirror: false,
        scrollMode: ScrollMode.voice.rawValue,
        constantSpeed: 40.0,
        soundThresholdDb: -45.0,
        recognitionLocale: "",
        audioInputUID: "",
        allowBackward: false,
        removeEmptyLines: false,
        lastScriptID: "",
    ]

    static func register() { UserDefaults.standard.register(defaults: defaults) }

    /// Apparence courante lue depuis UserDefaults.
    static func currentAppearance(_ d: UserDefaults = .standard) -> PrompterAppearance {
        PrompterAppearance(
            fontFamily: PrompterFontFamily(rawValue: d.string(forKey: fontFamily) ?? "") ?? .rounded,
            fontSize: d.double(forKey: fontSize),
            lineSpacing: d.double(forKey: lineSpacing),
            alignment: PrompterAlignment(rawValue: d.string(forKey: alignment) ?? "") ?? .left,
            backgroundOpacity: d.double(forKey: backgroundOpacity),
            dimSpokenText: d.bool(forKey: dimSpokenText),
            readingLine: d.double(forKey: readingLine),
            mirror: d.bool(forKey: mirror)
        )
    }
}
