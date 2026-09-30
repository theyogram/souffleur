import Foundation

final class ScriptMatcher {
    private let tokens: [ScriptToken]
    private let config: MatcherConfig
    private var finalized: [ScriptToken] = []
    private var volatile: [ScriptToken] = []
    private var lastAcceptedAt: Date?
    private var finalizedAtAcceptance = 0
    private var maximumPendingCount = 0
    private var index: [String: [Int]] = [:]
    private var similarityCache: [String: [String: Double]] = [:]
    private var similarityCacheCount = 0
    private(set) var cursor = -1
    var allowBackward: Bool
    private(set) var lastDebug = MatchDebugInfo()

    init(tokens: [ScriptToken], config: MatcherConfig = .default, allowBackward: Bool = false) {
        self.tokens = tokens
        self.config = config
        self.allowBackward = allowBackward
        for (position, token) in tokens.enumerated() where token.weight == 1 {
            index[token.key, default: []].append(position)
            if token.stem != token.key { index[token.stem, default: []].append(position) }
        }
    }

    @discardableResult
    func ingest(_ update: TranscriptUpdate) -> Bool {
        let heard = Tokenizer.tokenize(update.text)
        switch update.kind {
        case .volatile:
            volatile = heard
        case .final:
            finalized.append(contentsOf: heard)
            volatile.removeAll(keepingCapacity: true)
            if finalized.count > max(config.heardTailCount + config.globalUnacceptedTokens, 32) {
                let removed = finalized.count - max(config.heardTailCount + config.globalUnacceptedTokens, 32)
                finalized.removeFirst(removed)
                finalizedAtAcceptance = max(0, finalizedAtAcceptance - removed)
            }
        }
        if lastAcceptedAt == nil { lastAcceptedAt = update.timestamp }
        let tail = Array((finalized + volatile).suffix(config.heardTailCount))
        maximumPendingCount = max(maximumPendingCount, finalized.count - finalizedAtAcceptance + volatile.count)
        let lower = max(0, cursor - config.windowBehind)
        let upper = min(tokens.count - 1, cursor + config.windowAhead)
        var best: Candidate?
        if lower <= upper {
            let likely = localCandidates(for: tail, lower: lower, upper: upper)
            for end in likely {
                let candidate = align(tail, end: end)
                if isBetter(candidate, than: best) { best = candidate }
            }
            if best.map(accepts) != true, likely.count < upper - lower + 1 {
                let checked = Set(likely)
                for end in lower...upper where !checked.contains(end) {
                    let candidate = align(tail, end: end)
                    if isBetter(candidate, than: best) { best = candidate }
                }
            }
        }
        var accepted = best.map(accepts) ?? false
        var zone = best.map { zone(for: $0.end) } ?? "none"
        if !accepted, maximumPendingCount >= config.globalUnacceptedTokens,
           let lastAcceptedAt, update.timestamp.timeIntervalSince(lastAcceptedAt) >= config.globalSilenceSeconds {
            let candidates = globalCandidates(for: tail)
            for end in candidates {
                var candidate = align(tail, end: end)
                candidate.score += config.distancePenalty * Double(max(0, end - cursor - 1))
                if candidate.strong >= config.globalStrongMatches && candidate.score >= config.globalScore,
                   (end > cursor || allowBackward && candidate.exactRun >= config.backwardExactRun),
                   isBetter(candidate, than: best) {
                    best = candidate
                    accepted = true
                    zone = "global"
                }
            }
        }
        let old = cursor
        if accepted, let best {
            cursor = allowBackward ? best.end : max(cursor, best.end)
            if cursor != old {
                lastAcceptedAt = update.timestamp
                finalizedAtAcceptance = finalized.count
                maximumPendingCount = 0
            }
        }
        lastDebug = MatchDebugInfo(heardTail: tail.map(\.key), volatileText: update.kind == .volatile ? update.text : "",
                                   cursor: cursor, bestEnd: best?.end, score: best?.score ?? 0,
                                   zone: zone, accepted: accepted)
        return cursor != old
    }

    func reanchor(to wordIndex: Int) {
        cursor = min(max(-1, wordIndex), tokens.count - 1)
        clearHeard()
    }

    func reset() {
        cursor = -1
        clearHeard()
    }

    private func clearHeard() {
        finalized.removeAll()
        volatile.removeAll()
        lastAcceptedAt = nil
        finalizedAtAcceptance = 0
        maximumPendingCount = 0
        lastDebug = MatchDebugInfo(cursor: cursor)
    }

    private struct Candidate {
        var end: Int
        var score: Double
        var strong: Int
        var exactRun: Int
    }
    private struct Cell {
        var score = 0.0
        var strong = 0
        var exactRun = 0
        var lastRun = 0
    }

    private func align(_ heard: [ScriptToken], end: Int) -> Candidate {
        guard !heard.isEmpty, tokens.indices.contains(end) else {
            return Candidate(end: end, score: -.infinity, strong: 0, exactRun: 0)
        }
        let start = max(0, end - config.contextCount + 1)
        let width = end - start + 1
        var best = Candidate(end: end, score: -.infinity, strong: 0, exactRun: 0)
        var previous = Array(repeating: Cell(), count: width + 1)
        for row in 1...heard.count {
                var current = Array(repeating: Cell(), count: width + 1)
                let h = heard[row - 1]
                for column in 1...width {
                    let s = tokens[start + column - 1]
                    let similarity = similarity(h, s)
                    var diagonal = previous[column - 1]
                    diagonal.score += similarity == 0 ? config.mismatchPenalty : similarity * s.weight
                    if similarity > 0, s.weight == 1 { diagonal.strong += 1 }
                    diagonal.lastRun = similarity == config.exactSimilarity && s.weight == 1 ? diagonal.lastRun + 1 : 0
                    diagonal.exactRun = max(diagonal.exactRun, diagonal.lastRun)
                    var left = current[column - 1]
                    left.score += config.gapPenalty
                    left.lastRun = 0
                    var up = previous[column]
                    up.score += config.gapPenalty
                    up.lastRun = 0
                    var winner = Cell()
                    if diagonal.score > winner.score || diagonal.score == winner.score && diagonal.strong > winner.strong { winner = diagonal }
                    if left.score > winner.score || left.score == winner.score && left.strong > winner.strong { winner = left }
                    if up.score > winner.score || up.score == winner.score && up.strong > winner.strong { winner = up }
                    current[column] = winner
                }
                previous = current
            let trailing = heard.count - row
            if trailing <= config.maxUnmatchedHeardTail {
                let cell = previous[width]
                let score = cell.score + Double(trailing) * config.unmatchedTailPenalty
                    - config.distancePenalty * Double(max(0, end - cursor - 1))
                if score > best.score {
                    best = Candidate(end: end, score: score, strong: cell.strong, exactRun: cell.exactRun)
                }
            }
        }
        return best
    }

    private func similarity(_ heard: ScriptToken, _ script: ScriptToken) -> Double {
        if heard.key == script.key { return config.exactSimilarity }
        if heard.stem == script.stem { return config.approximateSimilarity }
        if let cached = similarityCache[heard.key]?[script.key] { return cached }
        let a = Array(heard.key.utf16), b = Array(script.key.utf16)
        guard a.count >= config.minimumApproximateLength, b.count >= config.minimumApproximateLength else { return 0 }
        let length = max(a.count, b.count)
        if Double(abs(a.count - b.count)) / Double(length) > 1 - config.levenshteinThreshold { return 0 }
        var prior = Array(0...b.count)
        for (i, character) in a.enumerated() {
            var next = Array(repeating: 0, count: b.count + 1)
            next[0] = i + 1
            for (j, other) in b.enumerated() {
                next[j + 1] = min(prior[j + 1] + 1, next[j] + 1, prior[j] + (character == other ? 0 : 1))
            }
            prior = next
        }
        let value = 1 - Double(prior[b.count]) / Double(length) >= config.levenshteinThreshold ? config.approximateSimilarity : 0
        if similarityCacheCount >= 8_192 {
            similarityCache.removeAll(keepingCapacity: true)
            similarityCacheCount = 0
        }
        similarityCache[heard.key, default: [:]][script.key] = value
        similarityCacheCount += 1
        return value
    }

    private func zone(for end: Int) -> String {
        if end < cursor { return "backward" }
        if end <= cursor + config.nearDistance { return "near" }
        return "medium"
    }

    private func accepts(_ candidate: Candidate) -> Bool {
        if candidate.end < cursor {
            return allowBackward && candidate.exactRun >= config.backwardExactRun
        }
        if candidate.end == cursor { return false }
        if candidate.end <= cursor + config.nearDistance {
            return candidate.score >= config.nearScore && candidate.strong >= config.nearStrongMatches
        }
        return candidate.score >= config.mediumScore && candidate.strong >= config.mediumStrongMatches
    }

    private func isBetter(_ candidate: Candidate, than current: Candidate?) -> Bool {
        guard let current else { return true }
        if candidate.score != current.score { return candidate.score > current.score }
        return abs(candidate.end - cursor) < abs(current.end - cursor)
    }

    private func globalCandidates(for heard: [ScriptToken]) -> [Int] {
        var positions = Set<Int>()
        for token in heard where token.weight == 1 {
            let matches = (index[token.key] ?? []) + (index[token.stem] ?? [])
            for position in matches where position > cursor || allowBackward {
                for offset in 0...config.maxUnmatchedHeardTail where position + offset < tokens.count {
                    positions.insert(position + offset)
                }
            }
        }
        return positions.sorted()
    }

    private func localCandidates(for heard: [ScriptToken], lower: Int, upper: Int) -> [Int] {
        var positions = Set<Int>()
        for token in heard where token.weight == 1 {
            for key in Set([token.key, token.stem]) {
                guard let matches = index[key] else { continue }
                var left = 0, right = matches.count
                while left < right {
                    let middle = (left + right) / 2
                    if matches[middle] < lower - 2 { left = middle + 1 } else { right = middle }
                }
                while left < matches.count, matches[left] <= upper {
                    let position = matches[left]
                    for offset in 0...2 where position + offset <= upper && position + offset >= lower {
                        positions.insert(position + offset)
                    }
                    left += 1
                }
            }
        }
        if positions.isEmpty { return Array(lower...upper) }
        return positions.sorted()
    }
}
