// Contrats partagés entre modules. FIGÉS : un worker ne modifie pas ce fichier.
// Si un contrat manque, il ajoute un type dans SON module et le signale dans son worker_done.
import AVFoundation
import Foundation

// MARK: - Tracking

/// Un mot du script (ou de la transcription), normalisé pour la correspondance. PRD §7.5.2
struct ScriptToken: Equatable, Sendable {
    /// Mot tel qu'affiché.
    var display: String
    /// Clé normalisée (minuscules, sans diacritiques ni ponctuation).
    var key: String
    /// Racine approximative (suffixes ent/es/s/x/e/t retirés, min 3 lettres).
    var stem: String
    /// Plage UTF-16 dans le texte d'origine (compatible NSString / NSTextView).
    var range: NSRange
    /// 1.0 = mot fort, 0.3 = mot faible.
    var weight: Double
}

/// Une mise à jour du moteur de reconnaissance. PRD §7.5.3
struct TranscriptUpdate: Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case volatile, final }
    var kind: Kind
    /// Texte du segment courant. Un `volatile` remplace le volatile précédent ; un `final` le fige.
    var text: String
    var timestamp: Date
}

// MARK: - Lecture

enum ScrollMode: String, CaseIterable, Codable, Sendable {
    case voice, constant, sound
}

enum PlaybackState: Equatable, Sendable {
    case idle
    case preparing(message: String?, progress: Double?)
    case listening
    case paused
    case error(String)

    var isRunning: Bool { if case .listening = self { true } else { false } }
}

// MARK: - Parole

/// Moteur de reconnaissance vocale en streaming. PRD §9.2
/// L'implémentation convertit elle-même les tampons audio vers son format interne.
protocol SpeechEngine: AnyObject {
    /// Flux des mises à jour. Un nouveau flux est créé à chaque `start`.
    var updates: AsyncStream<TranscriptUpdate> { get }
    /// Permissions + installation du modèle de langue. `progress` ∈ [0,1], appelé hors main thread.
    func prepare(locale: Locale, contextualWords: [String], progress: @escaping @Sendable (Double) -> Void) async throws
    /// Démarre l'analyse sur les tampons fournis (format natif du micro).
    func start(audio: AsyncStream<AVAudioPCMBuffer>) async throws
    func stop() async
}

// MARK: - Apparence (lue par le prompteur)

enum PrompterFontFamily: String, CaseIterable, Codable, Sendable {
    case system, rounded, serif, mono
}

enum PrompterAlignment: String, CaseIterable, Codable, Sendable {
    case left, center, right
}

struct PrompterAppearance: Equatable, Sendable {
    var fontFamily: PrompterFontFamily = .rounded
    var fontSize: Double = 32
    var lineSpacing: Double = 1.0
    var alignment: PrompterAlignment = .left
    var backgroundOpacity: Double = 0.35
    var dimSpokenText: Bool = true
    var readingLine: Double = 0.20
    var mirror: Bool = false
}
