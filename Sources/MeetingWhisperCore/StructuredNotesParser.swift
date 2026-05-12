import Foundation

public struct StructuredNotesParser: Sendable {
    public init() {}

    public func parse(_ response: String) throws -> StructuredNotes {
        let json = try extractJSONObject(from: response)
        let data = Data(json.utf8)
        return try JSONDecoder().decode(StructuredNotes.self, from: data)
    }

    private func extractJSONObject(from response: String) throws -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), trimmed.hasSuffix("}") {
            return trimmed
        }

        if let fenced = extractFencedJSON(from: trimmed) {
            return fenced
        }

        guard
            let start = trimmed.firstIndex(of: "{"),
            let end = trimmed.lastIndex(of: "}"),
            start <= end
        else {
            throw StructuredNotesParserError.noJSONObject
        }

        return String(trimmed[start...end])
    }

    private func extractFencedJSON(from response: String) -> String? {
        guard response.hasPrefix("```") else {
            return nil
        }
        let lines = response.split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.count >= 3, lines.last?.trimmingCharacters(in: .whitespaces) == "```" else {
            return nil
        }
        return lines.dropFirst().dropLast().joined(separator: "\n")
    }
}

public enum StructuredNotesParserError: Error, Equatable {
    case noJSONObject
}
