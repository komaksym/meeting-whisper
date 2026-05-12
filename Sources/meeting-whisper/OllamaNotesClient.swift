import Foundation
import MeetingWhisperCore

struct OllamaNotesClient {
    let model: String
    var endpoint = URL(string: "http://127.0.0.1:11434/api/generate")!

    func generateNotes(for transcript: MeetingTranscript) async throws -> StructuredNotes {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GenerateRequest(
                model: model,
                prompt: NotesPromptBuilder().prompt(for: transcript),
                stream: false
            )
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            return .transcriptOnlyFallback()
        }

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode)
        else {
            return .transcriptOnlyFallback()
        }

        let payload = try JSONDecoder().decode(GenerateResponse.self, from: data)
        return (try? StructuredNotesParser().parse(payload.response))
            ?? .transcriptOnlyFallback()
    }
}

private struct GenerateRequest: Encodable {
    var model: String
    var prompt: String
    var stream: Bool
}

private struct GenerateResponse: Decodable {
    var response: String
}
