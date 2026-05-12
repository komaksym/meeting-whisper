import Foundation

public enum RetentionPolicy: String, Codable, Equatable, Sendable {
    case transcriptOnly = "transcript-only"
    case keepAudioAndTranscript = "keep-audio-and-transcript"
    case notesOnly = "notes-only"
}

public struct AppConfig: Codable, Equatable, Sendable {
    public static let defaultWhisperModel = "large-v3-v20240930_626MB"
    public static let defaultOllamaModel = "llama3.2:3b"

    public var vaultPath: String
    public var notesFolder: String
    public var whisperModel: String
    public var language: String
    public var ollamaModel: String
    public var retention: RetentionPolicy

    public init(
        vaultPath: String,
        notesFolder: String = "Meetings",
        whisperModel: String = Self.defaultWhisperModel,
        language: String = "en",
        ollamaModel: String = Self.defaultOllamaModel,
        retention: RetentionPolicy = .transcriptOnly
    ) {
        self.vaultPath = vaultPath
        self.notesFolder = notesFolder
        self.whisperModel = whisperModel
        self.language = language
        self.ollamaModel = ollamaModel
        self.retention = retention
    }
}

public struct ConfigStore {
    public let configURL: URL
    private let fileManager: FileManager

    public init(
        configURL: URL = ConfigStore.defaultConfigURL(),
        fileManager: FileManager = .default
    ) {
        self.configURL = configURL
        self.fileManager = fileManager
    }

    public func load() throws -> AppConfig {
        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(AppConfig.self, from: data)
    }

    public func save(_ config: AppConfig) throws {
        let directory = configURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL, options: [.atomic])
    }

    public func loadIfPresent() throws -> AppConfig? {
        guard fileManager.fileExists(atPath: configURL.path) else {
            return nil
        }
        return try load()
    }

    public static func defaultConfigURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: ".config", directoryHint: .isDirectory)
            .appending(path: "meeting-whisper", directoryHint: .isDirectory)
            .appending(path: "config.json")
    }
}
