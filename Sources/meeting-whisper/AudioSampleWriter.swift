@preconcurrency import AVFoundation
import CoreMedia
import Foundation

final class AudioSampleWriter {
    let outputURL: URL
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var didStartSession = false

    init(outputURL: URL) {
        self.outputURL = outputURL
    }

    var didWriteSamples: Bool {
        writer != nil
    }

    func append(_ sampleBuffer: CMSampleBuffer) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            return
        }

        do {
            try ensureWriter()
        } catch {
            fputs("Audio writer error: \(error)\n", stderr)
            return
        }

        guard let writer, let input else {
            return
        }

        if writer.status == .unknown {
            writer.startWriting()
        }
        if !didStartSession {
            writer.startSession(
                atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            )
            didStartSession = true
        }
        if input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
    }

    func finish() async throws {
        guard let writer else {
            return
        }
        input?.markAsFinished()
        await writer.finishWriting()
        if writer.status == .failed, let error = writer.error {
            throw error
        }
    }

    private func ensureWriter() throws {
        guard writer == nil else {
            return
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000,
        ]
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(input) else {
            throw RecordingError.cannotAddAudioInput(outputURL.path)
        }
        writer.add(input)

        self.writer = writer
        self.input = input
    }
}

enum RecordingError: Error, CustomStringConvertible {
    case cannotAddAudioInput(String)
    case noSystemAudioCaptured
    case noMicrophoneAudioCaptured
    case noDisplayAvailable

    var description: String {
        switch self {
        case .cannotAddAudioInput(let path):
            return "Could not add audio writer input for \(path)."
        case .noSystemAudioCaptured:
            return "No system audio was captured."
        case .noMicrophoneAudioCaptured:
            return "No microphone audio was captured."
        case .noDisplayAvailable:
            return "No display was available for ScreenCaptureKit capture."
        }
    }
}
