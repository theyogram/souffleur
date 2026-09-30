import Foundation

enum SpeechSmokeTest {
    static func run(seconds: Int, deviceUID: String?) async {
        let capture = AudioCapture()
        let speech = AppleSpeechEngine()
        speech.onError = { error in print("speech error: \(error.localizedDescription)") }
        capture.onDeviceLost = { print("audio device lost; switched to default input") }
        do {
            try await speech.prepare(locale: Locale(identifier: "fr-FR"), contextualWords: []) { value in
                print(String(format: "model progress: %.0f%%", value * 100))
            }
            let audio = try capture.start(deviceUID: deviceUID)
            try await speech.start(audio: audio)
            let printing = Task {
                for await update in speech.updates {
                    let latency = max(0, Date().timeIntervalSince(update.timestamp)) * 1_000
                    print(String(format: "[%@] %.0f ms %@", update.kind.rawValue, latency, update.text))
                }
            }
            try await Task.sleep(for: .seconds(max(1, seconds)))
            capture.stop()
            await speech.stop()
            printing.cancel()
        } catch {
            capture.stop()
            await speech.stop()
            print("speech smoke test failed: \(error.localizedDescription)")
        }
    }
}
