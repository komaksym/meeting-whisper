import Foundation
import MeetingWhisperCore

@main
struct CoreTests {
    static func main() throws {
        try testConfigStore()
        testDefaultConfig()
        testNoteRendering()
        testTranscriptMerging()
        testRawSystemFallback()
        testNotePath()
        try testStructuredNotesParsing()
        try testRetentionCleanup()
        print("meeting-whisper-core-tests: all tests passed")
    }

    private static func testConfigStore() throws {
        let root = try TemporaryDirectory()
        let configURL = root.url.appending(path: "config.json")
        let store = ConfigStore(configURL: configURL)
        let config = AppConfig(
            vaultPath: "/Users/koval/Obsidian",
            notesFolder: "Meetings",
            whisperModel: AppConfig.defaultWhisperModel,
            language: "en",
            ollamaModel: AppConfig.defaultOllamaModel,
            retention: .transcriptOnly
        )

        try store.save(config)

        let loaded = try store.load()
        expectEqual(loaded, config, "config round trip")
    }

    private static func testDefaultConfig() {
        let config = AppConfig(vaultPath: "/vault")

        expectEqual(config.notesFolder, "Meetings", "default notes folder")
        expectEqual(config.whisperModel, "large-v3-v20240930_626MB", "default whisper model")
        expectEqual(config.language, "en", "default language")
        expectEqual(config.ollamaModel, "llama3.2:3b", "default ollama model")
        expectEqual(config.retention, .transcriptOnly, "default retention")
    }

    private static func testNoteRendering() {
        let createdAt = Date(timeIntervalSince1970: 1_704_067_200)
        let transcript = MeetingTranscript(
            title: "Weekly Coaching",
            createdAt: createdAt,
            segments: [
                TranscriptSegment(
                    start: 0,
                    end: 2.4,
                    speaker: "Me",
                    text: "What should I focus on this week?"
                ),
                TranscriptSegment(
                    start: 2.5,
                    end: 5.2,
                    speaker: "Other",
                    text: "Ship the smallest working version first."
                ),
            ]
        )
        let structured = StructuredNotes(
            summary: "Discussed the next implementation focus.",
            decisions: ["Start with a terminal CLI."],
            actionItems: ["Implement import mode before polishing recording."],
            openQuestions: ["Which meetings should be archived?"],
            followUps: ["Review the first generated note."]
        )

        let markdown = NoteRenderer().render(
            transcript: transcript,
            notes: structured,
            source: .recorded
        )

        expect(markdown.contains("title: \"Weekly Coaching\""), "front matter title")
        expect(markdown.contains("source: recorded"), "front matter source")
        expect(markdown.contains("## Summary\nDiscussed the next implementation focus."), "summary section")
        expect(markdown.contains("- Start with a terminal CLI."), "decisions list")
        expect(markdown.contains("`00:00` **Me:** What should I focus on this week?"), "me transcript line")
        expect(markdown.contains("`00:02` **Other:** Ship the smallest working version first."), "other transcript line")
    }

    private static func testTranscriptMerging() {
        let mic = [
            TranscriptSegment(start: 1.0, end: 2.0, speaker: "ignored", text: "My first line"),
            TranscriptSegment(start: 6.0, end: 7.0, speaker: "ignored", text: "My follow-up"),
        ]
        let rawSystem = [
            TranscriptSegment(start: 3.0, end: 4.0, speaker: "ignored", text: "Raw system")
        ]
        let diarizedSystem = [
            TranscriptSegment(start: 2.5, end: 3.0, speaker: "Speaker 0", text: "Their answer"),
            TranscriptSegment(start: 4.0, end: 5.0, speaker: "Speaker 1", text: "Extra voice"),
        ]

        let merged = TranscriptMerger().mergeRecordedTracks(
            mic: mic,
            system: rawSystem,
            diarizedSystem: diarizedSystem
        )

        expectEqual(merged.map(\.speaker), ["Me", "Other", "Other 2", "Me"], "merged speakers")
        expectEqual(merged.map(\.text), [
            "My first line",
            "Their answer",
            "Extra voice",
            "My follow-up",
        ], "merged transcript text")
    }

    private static func testRawSystemFallback() {
        let merged = TranscriptMerger().mergeRecordedTracks(
            mic: [],
            system: [
                TranscriptSegment(start: 2, end: 3, speaker: "whatever", text: "Hello")
            ],
            diarizedSystem: []
        )

        expectEqual(merged, [
            TranscriptSegment(start: 2, end: 3, speaker: "Other", text: "Hello")
        ], "raw system fallback")
    }

    private static func testNotePath() {
        let createdAt = Date(timeIntervalSince1970: 1_704_067_200)
        let config = AppConfig(vaultPath: "/vault", notesFolder: "Meetings/Calls")
        let url = ObsidianNotePathBuilder().noteURL(
            title: "Koval / Alex: Weekly Sync?",
            createdAt: createdAt,
            config: config
        )

        expectEqual(
            url.path,
            "/vault/Meetings/Calls/2024-01-01 0000 - koval-alex-weekly-sync.md",
            "note path"
        )
    }

    private static func testStructuredNotesParsing() throws {
        let response = """
        ```json
        {
          "summary": "Good meeting.",
          "decisions": ["Use Swift."],
          "actionItems": ["Record a fixture."],
          "openQuestions": [],
          "followUps": ["Review notes."]
        }
        ```
        """

        let notes = try StructuredNotesParser().parse(response)

        expectEqual(notes.summary, "Good meeting.", "parsed summary")
        expectEqual(notes.decisions, ["Use Swift."], "parsed decisions")
        expectEqual(notes.actionItems, ["Record a fixture."], "parsed action items")
        expectEqual(notes.openQuestions, [] as [String], "parsed open questions")
        expectEqual(notes.followUps, ["Review notes."], "parsed follow ups")
    }

    private static func testRetentionCleanup() throws {
        let root = try TemporaryDirectory()
        let system = root.url.appending(path: "system.m4a")
        let mic = root.url.appending(path: "mic.m4a")
        try Data("system".utf8).write(to: system)
        try Data("mic".utf8).write(to: mic)

        try RetentionManager(fileManager: .default).apply(
            .transcriptOnly,
            to: [system, mic]
        )

        expect(!FileManager.default.fileExists(atPath: system.path), "system raw audio deleted")
        expect(!FileManager.default.fileExists(atPath: mic.path), "mic raw audio deleted")
    }
}

private struct TemporaryDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fatalError("Expectation failed: \(message)")
    }
}

private func expectEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ message: String
) {
    guard actual == expected else {
        fatalError("Expectation failed: \(message)\nActual: \(actual)\nExpected: \(expected)")
    }
}
