import Foundation

public struct TranscriptSegment: Codable, Equatable, Sendable {
    public var start: Double
    public var end: Double
    public var speaker: String
    public var text: String

    public init(start: Double, end: Double, speaker: String, text: String) {
        self.start = start
        self.end = end
        self.speaker = speaker
        self.text = text
    }

    public func withSpeaker(_ speaker: String) -> TranscriptSegment {
        TranscriptSegment(start: start, end: end, speaker: speaker, text: text)
    }
}

public struct MeetingTranscript: Codable, Equatable, Sendable {
    public var title: String
    public var createdAt: Date
    public var segments: [TranscriptSegment]

    public init(
        title: String,
        createdAt: Date,
        segments: [TranscriptSegment]
    ) {
        self.title = title
        self.createdAt = createdAt
        self.segments = segments
    }
}

public struct TranscriptMerger: Sendable {
    public init() {}

    public func mergeRecordedTracks(
        mic: [TranscriptSegment],
        system: [TranscriptSegment],
        diarizedSystem: [TranscriptSegment]
    ) -> [TranscriptSegment] {
        let me = mic.map { $0.withSpeaker("Me") }
        let otherSource = diarizedSystem.isEmpty ? system : diarizedSystem
        let other = otherSource.map { segment in
            segment.withSpeaker(normalizedOtherSpeaker(from: segment.speaker))
        }

        return (me + other).sorted { left, right in
            if left.start == right.start {
                return left.end < right.end
            }
            return left.start < right.start
        }
    }

    public func mergeImportedSegments(
        diarized: [TranscriptSegment],
        fallback: [TranscriptSegment]
    ) -> [TranscriptSegment] {
        let source = diarized.isEmpty ? fallback : diarized
        return source
            .map { $0.withSpeaker(normalizedImportedSpeaker(from: $0.speaker)) }
            .sorted { $0.start < $1.start }
    }

    private func normalizedOtherSpeaker(from speaker: String) -> String {
        guard let id = speakerID(from: speaker) else {
            return "Other"
        }
        return id == 0 ? "Other" : "Other \(id + 1)"
    }

    private func normalizedImportedSpeaker(from speaker: String) -> String {
        guard let id = speakerID(from: speaker) else {
            return speaker.isEmpty ? "Speaker 1" : speaker
        }
        return "Speaker \(id + 1)"
    }

    private func speakerID(from speaker: String) -> Int? {
        let trimmed = speaker.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("speaker") else {
            return nil
        }
        return trimmed
            .split(separator: " ")
            .last
            .flatMap { Int($0) }
    }
}
