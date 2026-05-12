import Foundation

struct RecordingArtifacts {
    let systemAudioURL: URL
    let microphoneAudioURL: URL

    var allAudioURLs: [URL] {
        [systemAudioURL, microphoneAudioURL]
    }
}
