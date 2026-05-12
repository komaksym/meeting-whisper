import Foundation

public enum TranscriptSource: String, Codable, Equatable, Sendable {
    case recorded
    case imported
}

public struct StructuredNotes: Codable, Equatable, Sendable {
    public var summary: String
    public var decisions: [String]
    public var actionItems: [String]
    public var openQuestions: [String]
    public var followUps: [String]

    public init(
        summary: String,
        decisions: [String],
        actionItems: [String],
        openQuestions: [String],
        followUps: [String]
    ) {
        self.summary = summary
        self.decisions = decisions
        self.actionItems = actionItems
        self.openQuestions = openQuestions
        self.followUps = followUps
    }

    public static func transcriptOnlyFallback() -> StructuredNotes {
        StructuredNotes(
            summary: "Summary generation was unavailable. Review the transcript below.",
            decisions: [],
            actionItems: [],
            openQuestions: [],
            followUps: []
        )
    }
}

public struct NoteRenderer: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        var calendar = calendar
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        self.calendar = calendar
    }

    public func render(
        transcript: MeetingTranscript,
        notes: StructuredNotes,
        source: TranscriptSource
    ) -> String {
        let iso = ISO8601DateFormatter()
        let createdAt = iso.string(from: transcript.createdAt)

        return """
        ---
        title: "\(escapeFrontMatter(transcript.title))"
        created: \(createdAt)
        source: \(source.rawValue)
        language: en
        ---

        # \(transcript.title)

        ## Summary
        \(notes.summary)

        ## Decisions
        \(renderList(notes.decisions))

        ## Action Items
        \(renderList(notes.actionItems))

        ## Open Questions
        \(renderList(notes.openQuestions))

        ## Follow-ups
        \(renderList(notes.followUps))

        ## Speaker Transcript
        \(renderTranscript(transcript.segments))
        """
    }

    private func renderList(_ values: [String]) -> String {
        guard !values.isEmpty else {
            return "- None"
        }
        return values.map { "- \($0)" }.joined(separator: "\n")
    }

    private func renderTranscript(_ segments: [TranscriptSegment]) -> String {
        guard !segments.isEmpty else {
            return "_No transcript segments were produced._"
        }
        return segments.map { segment in
            "`\(timestamp(segment.start))` **\(segment.speaker):** \(segment.text)"
        }.joined(separator: "\n")
    }

    private func timestamp(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func escapeFrontMatter(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "\\\"")
    }
}
