import Foundation

enum VocabularyExtractor {
    // Liste courte embarquée : les mots courants ne biaisent pas la reconnaissance.
    private static let frequent: Set<String> = Tokenizer.stopwords.union([
        "avec", "pour", "dans", "mais", "plus", "comme", "cette", "cela", "nous", "vous", "leur", "leurs", "tout", "tous", "bien", "fait", "faire", "avoir", "etre", "sont", "elle", "elles", "parce", "quand", "alors", "encore", "entre", "apres", "avant", "autre", "autres", "meme", "aussi", "temps", "jour", "jours", "monde", "chose", "choses", "personne", "personnes", "parler", "texte", "phrase", "script", "video", "merci", "bonjour", "there", "their", "about", "would", "could", "these", "those", "which", "where", "after", "before", "other", "people", "first"
    ])

    static func contextualWords(in text: String, limit: Int = 100) -> [String] {
        guard limit > 0 else { return [] }
        let source = text as NSString
        var seen = Set<String>()
        var words: [String] = []
        for token in Tokenizer.tokenize(text) where token.weight == 1 && token.key.count >= 5 {
            guard !frequent.contains(token.key), seen.insert(token.key).inserted else { continue }
            // Le mot d'origine conserve la casse utile aux noms propres.
            let candidate = source.substring(with: token.range)
            words.append(candidate)
            if words.count == limit { break }
        }
        return words
    }
}
