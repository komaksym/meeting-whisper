import Foundation

public struct NotesPromptBuilder: Sendable {
    public init() {}

    public func prompt(for transcript: MeetingTranscript) -> String {
        """
        You turn English meeting transcripts into concise Obsidian notes.
        Return strict JSON with these keys:
        summary: string
        decisions: string[]
        actionItems: string[]
        openQuestions: string[]
        followUps: string[]

        Rules:
        - Use concrete wording.
        - Preserve action owners when the transcript makes them clear.
        - If a section has nothing useful, return an empty array.
        - Do not invent facts.

        Transcript:
        \(transcript.segments.map { segment in
            "[\(format(segment.start))] \(segment.speaker): \(segment.text)"
        }.joined(separator: "\n"))
        """
    }

    private func format(_ seconds: Double) -> String {
        String(format: "%.1fs", seconds)
    }
}
