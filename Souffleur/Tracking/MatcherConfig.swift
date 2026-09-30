import Foundation

struct MatcherConfig {
    var heardTailCount = 8
    var windowBehind = 2
    var windowAhead = 40
    var contextCount = 12
    var maxUnmatchedHeardTail = 2
    var exactSimilarity = 1.0
    var approximateSimilarity = 0.8
    var levenshteinThreshold = 0.75
    var minimumApproximateLength = 4
    var mismatchPenalty = -0.5
    var gapPenalty = -0.4
    var unmatchedTailPenalty = -0.3
    var distancePenalty = 0.03
    var nearDistance = 6
    var nearScore = 1.0
    var nearStrongMatches = 1
    var mediumScore = 2.2
    var mediumStrongMatches = 2
    var backwardExactRun = 4
    var globalSilenceSeconds = 6.0
    var globalUnacceptedTokens = 12
    var globalStrongMatches = 5
    var globalScore = 4.5
    static let `default` = MatcherConfig()
}

struct MatchDebugInfo: Equatable {
    var heardTail: [String] = []
    var volatileText = ""
    var cursor = -1
    var bestEnd: Int? = nil
    var score = 0.0
    var zone = "none"
    var accepted = false
}
