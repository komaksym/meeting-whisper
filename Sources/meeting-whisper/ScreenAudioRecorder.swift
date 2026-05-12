import AVFoundation
import Foundation
import ScreenCaptureKit

@available(macOS 15.0, *)
final class ScreenAudioRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private let queue = DispatchQueue(label: "meeting-whisper.screen-audio")
    private let systemWriter: AudioSampleWriter
    private let microphoneWriter: AudioSampleWriter
    private var stream: SCStream?

    init(outputDirectory: URL) throws {
        let systemURL = outputDirectory.appending(path: "system.m4a")
        let microphoneURL = outputDirectory.appending(path: "microphone.m4a")
        self.systemWriter = AudioSampleWriter(outputURL: systemURL)
        self.microphoneWriter = AudioSampleWriter(outputURL: microphoneURL)
        super.init()
    }

    func start() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let display = content.displays.first else {
            throw RecordingError.noDisplayAvailable
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = 2
        configuration.height = 2
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        configuration.capturesAudio = true
        configuration.captureMicrophone = true
        configuration.excludesCurrentProcessAudio = true

        let stream = SCStream(
            filter: filter,
            configuration: configuration,
            delegate: self
        )
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
        self.stream = stream
        try await stream.startCapture()
    }

    func stop() async throws -> RecordingArtifacts {
        try await stream?.stopCapture()
        try await systemWriter.finish()
        try await microphoneWriter.finish()

        guard systemWriter.didWriteSamples else {
            throw RecordingError.noSystemAudioCaptured
        }
        guard microphoneWriter.didWriteSamples else {
            throw RecordingError.noMicrophoneAudioCaptured
        }

        return RecordingArtifacts(
            systemAudioURL: systemWriter.outputURL,
            microphoneAudioURL: microphoneWriter.outputURL
        )
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        if outputType == .audio {
            systemWriter.append(sampleBuffer)
        } else if outputType == .microphone {
            microphoneWriter.append(sampleBuffer)
        }
    }
}
