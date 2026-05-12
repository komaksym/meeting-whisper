import ArgumentParser
import Foundation
import MeetingWhisperCore

@main
struct MeetingWhisperCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "meeting-whisper",
        abstract: "Record or import English meetings and save speaker-labelled notes to Obsidian.",
        subcommands: [
            Setup.self,
            ImportAudio.self,
            Record.self,
            Doctor.self,
        ],
        defaultSubcommand: Doctor.self
    )
}

struct Setup: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Save local Obsidian and model settings."
    )

    @Option(help: "Absolute path to the Obsidian vault.")
    var vault: String

    @Option(help: "Folder inside the Obsidian vault.")
    var folder: String = "Meetings"

    @Option(help: "WhisperKit model name.")
    var whisperModel: String = AppConfig.defaultWhisperModel

    @Option(help: "Ollama model used for note generation.")
    var ollamaModel: String = AppConfig.defaultOllamaModel

    func run() throws {
        let config = AppConfig(
            vaultPath: URL(filePath: vault).standardizedFileURL.path,
            notesFolder: folder,
            whisperModel: whisperModel,
            language: "en",
            ollamaModel: ollamaModel,
            retention: .transcriptOnly
        )
        try ConfigStore().save(config)
        print("Saved config to \(ConfigStore.defaultConfigURL().path)")
    }
}

struct ImportAudio: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "import",
        abstract: "Process an existing audio file into an Obsidian meeting note."
    )

    @Argument(help: "Path to an audio file supported by WhisperKit.")
    var audioFile: String

    @Option(help: "Meeting title for the Obsidian note.")
    var title: String

    @Flag(help: "Delete the source audio file after successful note creation.")
    var deleteSourceAudio = false

    mutating func run() async throws {
        let config = try loadRequiredConfig()
        let audioURL = URL(filePath: audioFile).standardizedFileURL
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw CLIError.audioFileMissing(audioURL.path)
        }

        let processor = SpeechProcessor(config: config)
        let plain = try await processor.transcribe(audioURL: audioURL, speaker: "Speaker 1")
        let diarized = try await processor.diarizedTranscription(
            audioURL: audioURL,
            speakerPrefix: "Speaker"
        )
        let segments = TranscriptMerger().mergeImportedSegments(
            diarized: diarized,
            fallback: plain
        )

        let noteURL = try await writeNote(
            title: title,
            segments: segments,
            source: .imported,
            config: config
        )

        if deleteSourceAudio {
            try RetentionManager().apply(.transcriptOnly, to: [audioURL])
        }

        print("Saved note: \(noteURL.path)")
    }
}

struct Record: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Record system audio and microphone, then process after stop."
    )

    @Option(help: "Meeting title for the Obsidian note.")
    var title: String

    @Option(help: "Optional display name for the other participant.")
    var other: String?

    mutating func run() async throws {
        let config = try loadRequiredConfig()
        let recordingDirectory = FileManager.default.temporaryDirectory
            .appending(path: "meeting-whisper-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: recordingDirectory,
            withIntermediateDirectories: true
        )

        guard #available(macOS 15.0, *) else {
            throw CLIError.macOSVersionTooOld
        }

        let recorder = try ScreenAudioRecorder(outputDirectory: recordingDirectory)
        print("Recording system audio + microphone. Press Return to stop.")
        try await recorder.start()
        _ = readLine()
        let artifacts = try await recorder.stop()

        let processor = SpeechProcessor(config: config)
        let mic = try await processor.transcribe(
            audioURL: artifacts.microphoneAudioURL,
            speaker: "Me"
        )
        let rawSystem = try await processor.transcribe(
            audioURL: artifacts.systemAudioURL,
            speaker: other ?? "Other"
        )
        let diarizedSystem = try await processor.diarizedTranscription(
            audioURL: artifacts.systemAudioURL,
            speakerPrefix: "Speaker"
        )
        let segments = TranscriptMerger().mergeRecordedTracks(
            mic: mic,
            system: rawSystem,
            diarizedSystem: diarizedSystem
        )

        let noteURL = try await writeNote(
            title: title,
            segments: segments,
            source: .recorded,
            config: config
        )

        try RetentionManager().apply(config.retention, to: artifacts.allAudioURLs)
        try? FileManager.default.removeItem(at: recordingDirectory)

        print("Saved note: \(noteURL.path)")
    }
}

struct Doctor: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check local setup."
    )

    func run() throws {
        print("Config: \(ConfigStore.defaultConfigURL().path)")
        if let config = try ConfigStore().loadIfPresent() {
            print("Vault: \(config.vaultPath)")
            print("Folder: \(config.notesFolder)")
            print("WhisperKit model: \(config.whisperModel)")
            print("Language: \(config.language)")
            print("Ollama model: \(config.ollamaModel)")
            print("Retention: \(config.retention.rawValue)")
        } else {
            print("Config missing. Run: meeting-whisper setup --vault /path/to/vault")
        }

        print("Ollama: \(isExecutableOnPath("ollama") ? "found" : "not found")")
        print("ffmpeg: \(isExecutableOnPath("ffmpeg") ? "found" : "not found")")
        if #available(macOS 15.0, *) {
            print("ScreenCaptureKit microphone capture: available")
        } else {
            print("ScreenCaptureKit microphone capture: requires macOS 15+")
        }
    }
}

private func loadRequiredConfig() throws -> AppConfig {
    guard let config = try ConfigStore().loadIfPresent() else {
        throw CLIError.configMissing(ConfigStore.defaultConfigURL().path)
    }
    return config
}

private func writeNote(
    title: String,
    segments: [TranscriptSegment],
    source: TranscriptSource,
    config: AppConfig
) async throws -> URL {
    let transcript = MeetingTranscript(
        title: title,
        createdAt: Date(),
        segments: segments
    )
    let notes = try await OllamaNotesClient(model: config.ollamaModel)
        .generateNotes(for: transcript)
    let markdown = NoteRenderer().render(
        transcript: transcript,
        notes: notes,
        source: source
    )
    let noteURL = ObsidianNotePathBuilder().noteURL(
        title: title,
        createdAt: transcript.createdAt,
        config: config
    )
    try FileManager.default.createDirectory(
        at: noteURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try markdown.write(to: noteURL, atomically: true, encoding: .utf8)
    return noteURL
}

private func isExecutableOnPath(_ name: String) -> Bool {
    let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
    return path
        .split(separator: ":")
        .map(String.init)
        .contains { directory in
            let url = URL(filePath: directory).appending(path: name)
            return FileManager.default.isExecutableFile(atPath: url.path)
        }
}

enum CLIError: Error, CustomStringConvertible {
    case configMissing(String)
    case audioFileMissing(String)
    case macOSVersionTooOld

    var description: String {
        switch self {
        case .configMissing(let path):
            return "Missing config at \(path). Run setup first."
        case .audioFileMissing(let path):
            return "Audio file does not exist: \(path)"
        case .macOSVersionTooOld:
            return "Recording mic + system audio requires macOS 15 or newer."
        }
    }
}
