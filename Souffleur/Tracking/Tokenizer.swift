import Foundation

enum Tokenizer {
    static let stopwords: Set<String> = [
        "le", "la", "les", "de", "des", "du", "un", "une", "et", "a", "en", "que", "qui", "ne", "pas", "je", "tu", "il", "on", "ce", "se", "sa", "son", "au", "aux", "l", "d", "j", "n", "s", "c", "qu", "m", "t",
        "the", "an", "of", "to", "and", "is", "it", "in", "that"
    ]
    private static let pattern = try! NSRegularExpression(pattern: "[\\p{L}\\p{N}]+(?:['’ʼ`][\\p{L}\\p{N}]+)*|[€$%&]")

    static func tokenize(_ text: String) -> [ScriptToken] {
        let source = text as NSString
        let matches = pattern.matches(in: text, range: NSRange(location: 0, length: source.length))
        var result: [ScriptToken] = []
        result.reserveCapacity(matches.count)
        for match in matches {
            let raw = source.substring(with: match.range)
            let unified = raw.replacingOccurrences(of: "’", with: "'")
                .replacingOccurrences(of: "ʼ", with: "'")
                .replacingOccurrences(of: "`", with: "'")
            if unified.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) == "aujourd'hui" {
                result.append(token(display: raw, key: "aujourdhui", range: match.range))
                continue
            }
            var offset = 0
            for part in unified.split(separator: "'", omittingEmptySubsequences: true) {
                let length = (String(part) as NSString).length
                let partRange = NSRange(location: match.range.location + offset, length: length)
                let display = source.substring(with: partRange)
                result.append(token(display: display, key: normalize(display), range: partRange))
                offset += length + 1
            }
        }
        return result
    }

    private static func normalize(_ word: String) -> String {
        switch word {
        case "€": return "euros"
        case "$": return "dollars"
        case "%": return "pourcent"
        case "&": return "et"
        default: return word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil).lowercased()
        }
    }

    private static func token(display: String, key: String, range: NSRange) -> ScriptToken {
        var stem = key
        for suffix in ["ent", "es", "s", "x", "e", "t"] where stem.hasSuffix(suffix) {
            let shortened = String(stem.dropLast(suffix.count))
            if shortened.count >= 3 {
                stem = shortened
                break
            }
        }
        return ScriptToken(display: display, key: key, stem: stem, range: range,
                           weight: key.count <= 2 || stopwords.contains(key) ? 0.3 : 1.0)
    }
}
