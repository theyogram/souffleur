import Foundation

struct Script: Codable, Identifiable, Equatable {
    var id: UUID
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var lastCharOffset: Int

    var title: String {
        body.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
            .map { String($0.prefix(80)) } ?? "Sans titre"
    }

    var wordCount: Int {
        body.split(whereSeparator: { $0.isWhitespace }).count
    }
}
