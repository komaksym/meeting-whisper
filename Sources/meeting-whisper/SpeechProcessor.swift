import Foundation
import MeetingWhisperCore
import SpeakerKit
import WhisperKit

final class SpeechProcessor {
    private let config: AppConfig
    private var whisperKit: WhisperKit?

    init(config: AppConfig) {
        self.config = config
    }

    func transcribe(audioURL: URL, speaker: String) async throws -> [TranscriptSegment] {
        let results = try await transcribeRaw(audioURL: audioURL)
        let merged = TranscriptionUtilities.mergeTranscriptionResults(results)
        return merged.segments.map { segment in
            TranscriptSegment(
                start: Double(segment.start),
                end: Double(segment.end),
                speaker: speaker,
                text: segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }.filter { !$0.text.isEmpty }
    }

    func diarizedTranscription(
        audioURL: URL,
        speakerPrefix: String
    ) async throws -> [TranscriptSegment] {
        let transcriptionResults = try await transcribeRaw(audioURL: audioURL)
        let audioFrames = try AudioProcessor.loadAudioAsFloatArray(
            fromPath: audioURL.path
        )
        let speakerKit = try await SpeakerKit(
            PyannoteConfig(
                download: true,
                load: false,
                verbose: false,
                concurrentSegmenterWorkers: 2,
                concurrentEmbedderWorkers: 2
            )
        )
        let diarization = try await speakerKit.diarize(
            audioArray: audioFrames,
            options: PyannoteDiarizationOptions(useExclusiveReconciliation: true)
        )
        await speakerKit.unloadModels()

        let grouped = diarization.addSpeakerInfo(
            to: transcriptionResults,
            strategy: .subsegment
        )

        return grouped.flatMap { segments in
            segments.map { segment in
                let speakerID = segment.speaker.speakerId ?? 0
                let label = "\(speakerPrefix) \(speakerID)"
                let start = segment.speakerWords.first?.wordTiming.start
                    ?? segment.startTime
                let end = segment.speakerWords.last?.wordTiming.end
                    ?? segment.endTime
                let text = segment.text.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                return TranscriptSegment(
                    start: Double(start),
                    end: Double(end),
                    speaker: label,
                    text: text
                )
            }
        }.filter { !$0.text.isEmpty }
    }

    private func transcribeRaw(audioURL: URL) async throws -> [TranscriptionResult] {
        let whisperKit = try await loadWhisperKit()
        let options = DecodingOptions(
            language: config.language,
            detectLanguage: false,
            wordTimestamps: true,
            concurrentWorkerCount: 1,
            chunkingStrategy: .vad
        )
        return try await whisperKit.transcribe(
            audioPath: audioURL.path,
            decodeOptions: options
        )
    }

    private func loadWhisperKit() async throws -> WhisperKit {
        if let whisperKit {
            return whisperKit
        }
        let loaded = try await WhisperKit(
            WhisperKitConfig(
                model: config.whisperModel,
                verbose: false,
                prewarm: true,
                load: false,
                download: true
            )
        )
        whisperKit = loaded
        return loaded
    }
}
