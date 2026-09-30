import XCTest
@testable import Souffleur

final class LocaleResolverTests: XCTestCase {
    func testFrenchScriptUsesFrenchLocale() async {
        let text = "Bonjour, aujourd'hui nous allons parler de la création de vidéos. Cette histoire commence en France, avec une idée simple et quelques amis."
        let locale = await LocaleResolver.resolve(scriptText: text, preferredIdentifier: nil)
        XCTAssertEqual(locale.language.languageCode?.identifier, "fr")
    }

    func testBelgianFrenchFallsBackToSupportedFrench() async {
        let supported = await LocaleResolver.supportedLocales()
        let locale = await LocaleResolver.resolve(scriptText: "Bonjour tout le monde.", preferredIdentifier: "fr-BE")
        XCTAssertEqual(locale.language.languageCode?.identifier, "fr")
        XCTAssertTrue(supported.contains(where: { $0.identifier == locale.identifier }))
        if !supported.contains(where: { $0.language.languageCode?.identifier == "fr" && $0.region?.identifier == "BE" }) {
            XCTAssertEqual(locale.region?.identifier, "FR")
        }
    }

    func testEnglishScriptUsesEnglishLocale() async {
        let text = "Today we are going to discuss how to record a clear video. The script guides your words while you speak naturally to the camera."
        let locale = await LocaleResolver.resolve(scriptText: text, preferredIdentifier: nil)
        XCTAssertEqual(locale.language.languageCode?.identifier, "en")
    }
}
