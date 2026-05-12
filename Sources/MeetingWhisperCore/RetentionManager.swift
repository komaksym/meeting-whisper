import Foundation

public struct RetentionManager {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func apply(_ policy: RetentionPolicy, to rawAudioURLs: [URL]) throws {
        switch policy {
        case .transcriptOnly, .notesOnly:
            for url in rawAudioURLs where fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        case .keepAudioAndTranscript:
            break
        }
    }
}
