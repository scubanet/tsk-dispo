import Foundation

/// Thin client for the ElevenLabs REST API (Text-to-Speech + Scribe STT).
///
/// Endpoints used:
///   1. `GET  /v1/voices`                       — list available voices
///   2. `POST /v1/text-to-speech/{voice_id}`    — synthesise text to MP3 bytes
///   3. `POST /v1/speech-to-text`               — transcribe audio via Scribe
///
/// We use the non-streaming TTS endpoint. Per-sentence latency is ~500–1200ms,
/// which is acceptable for our use (sentences flushed as Claude streams).
/// Switch to `/v1/text-to-speech/{voice_id}/stream` later if needed.
public struct ElevenLabsClient: Sendable {
  public let apiKey: String
  public let session: URLSession

  public init(apiKey: String, session: URLSession = .shared) {
    self.apiKey = apiKey
    self.session = session
  }

  public struct Voice: Sendable, Codable, Identifiable, Hashable {
    public let voice_id: String
    public let name: String
    public let category: String?
    public var id: String { voice_id }
  }

  private struct VoicesResponse: Decodable {
    let voices: [Voice]
  }

  /// Fetches the list of voices accessible to this API key. Free-tier
  /// users see ~10 default voices; paid tiers can clone their own.
  public func listVoices() async throws -> [Voice] {
    var req = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/voices")!)
    req.httpMethod = "GET"
    req.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
    req.setValue("application/json", forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: req)
    try Self.checkOK(response)
    return try JSONDecoder().decode(VoicesResponse.self, from: data).voices
  }

  /// Synthesises `text` with the given voice. Returns raw audio bytes
  /// (MP3 mono, 44.1 kHz by default). Caller is responsible for playback.
  public func synthesize(
    text: String,
    voiceID: String,
    modelID: String = "eleven_multilingual_v2"
  ) async throws -> Data {
    let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)")!
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("audio/mpeg", forHTTPHeaderField: "Accept")

    let body: [String: Any] = [
      "text": text,
      "model_id": modelID,
      "voice_settings": [
        "stability": 0.5,
        "similarity_boost": 0.75,
      ],
    ]
    req.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await session.data(for: req)
    try Self.checkOK(response)
    return data
  }

  public enum Error: Swift.Error, Equatable {
    case unauthorized
    case rateLimit
    case server(code: Int, body: String)
    case network(String)
  }

  private static func checkOK(_ response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse else {
      throw Error.network("non-HTTP response")
    }
    switch http.statusCode {
    case 200..<300: return
    case 401: throw Error.unauthorized
    case 429: throw Error.rateLimit
    default:
      throw Error.server(code: http.statusCode, body: "")
    }
  }
}

// MARK: - Scribe (Speech-to-Text)

public extension ElevenLabsClient {
  /// Public result of a Scribe transcription: the text plus the
  /// detected language code (ISO 639-3 like "deu"/"ukr", per Scribe).
  struct Transcription: Sendable, Decodable, Equatable {
    public let text: String
    public let languageCode: String?
    public let languageProbability: Double?

    public init(text: String, languageCode: String?, languageProbability: Double?) {
      self.text = text
      self.languageCode = languageCode
      self.languageProbability = languageProbability
    }

    enum CodingKeys: String, CodingKey {
      case text
      case languageCode = "language_code"
      case languageProbability = "language_probability"
    }
  }

  /// Transcribe audio via Scribe (ElevenLabs Speech-to-Text).
  /// Audio: WAV-encoded (16 kHz mono Int16 recommended). Returns the
  /// transcript **and** the detected language. Throws `ElevenLabsClient.Error`.
  func transcribe(
    audioData: Data,
    modelID: String = "scribe_v1"   // TODO(open point #1): switch to Scribe v2 id once confirmed
  ) async throws -> Transcription {
    let url = URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

    let boundary = "Atoll-\(UUID().uuidString)"
    request.setValue(
      "multipart/form-data; boundary=\(boundary)",
      forHTTPHeaderField: "Content-Type"
    )
    request.httpBody = Self.multipartBody(
      boundary: boundary,
      fields: [
        "model_id":               modelID,
        "tag_audio_events":       "false",
        "timestamps_granularity": "none",
        "diarize":                "false",
      ],
      file: (name: "file", filename: "audio.wav", mime: "audio/wav", data: audioData)
    )

    let (data, response) = try await session.data(for: request)
    try Self.checkOK(response)
    return try JSONDecoder().decode(Transcription.self, from: data)
  }

  /// Build a multipart/form-data body with text fields + one file part.
  internal static func multipartBody(
    boundary: String,
    fields: [String: String],
    file: (name: String, filename: String, mime: String, data: Data)
  ) -> Data {
    var body = Data()
    let nl = "\r\n"
    let dashBoundary = "--\(boundary)"

    for (key, value) in fields {
      body.append("\(dashBoundary)\(nl)".data(using: .utf8)!)
      body.append("Content-Disposition: form-data; name=\"\(key)\"\(nl)\(nl)".data(using: .utf8)!)
      body.append("\(value)\(nl)".data(using: .utf8)!)
    }

    body.append("\(dashBoundary)\(nl)".data(using: .utf8)!)
    body.append(
      "Content-Disposition: form-data; name=\"\(file.name)\"; filename=\"\(file.filename)\"\(nl)"
        .data(using: .utf8)!
    )
    body.append("Content-Type: \(file.mime)\(nl)\(nl)".data(using: .utf8)!)
    body.append(file.data)
    body.append("\(nl)\(dashBoundary)--\(nl)".data(using: .utf8)!)

    return body
  }
}
