import Foundation

/// `SpeechBackend` that talks to the AtollTalk `speech` Edge Function instead
/// of ElevenLabs directly — the API key stays server-side.
///
/// Auth model:
///   - STT: anonymous install UUID (`x-atoll-device`, always) plus an optional
///     StoreKit 2 signed transaction (`x-atoll-jws`) that upgrades the daily cap.
///   - TTS: Pro-only; the JWS header is required (no JWS → `.unauthorized`
///     before any network call).
///
/// Errors map onto `ElevenLabsClient.Error` so callers don't care which
/// backend is wired.
public struct ProxySpeechClient: SpeechBackend {
  public let baseURL: URL
  public let deviceID: String
  public let jws: @Sendable () async -> String?
  public let session: URLSession

  /// - baseURL: function root, e.g. `https://<ref>.supabase.co/functions/v1/speech`
  /// - deviceID: stable anonymous install UUID (rate-limit key for Free).
  /// - jws: returns the current StoreKit 2 `jwsRepresentation`, or nil (Free).
  public init(
    baseURL: URL,
    deviceID: String,
    jws: @escaping @Sendable () async -> String? = { nil },
    session: URLSession = .shared
  ) {
    self.baseURL = baseURL
    self.deviceID = deviceID
    self.jws = jws
    self.session = session
  }

  public func transcribe(
    audioData: Data,
    modelID: String  // pinned server-side; kept for SpeechBackend conformance
  ) async throws -> ElevenLabsClient.Transcription {
    var req = URLRequest(url: baseURL.appendingPathComponent("stt"))
    req.httpMethod = "POST"
    req.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
    req.setValue(deviceID, forHTTPHeaderField: "x-atoll-device")
    if let token = await jws() {
      req.setValue(token, forHTTPHeaderField: "x-atoll-jws")
    }
    req.httpBody = audioData
    let (data, response) = try await session.data(for: req)
    try Self.checkOK(response, body: data)
    return try JSONDecoder().decode(ElevenLabsClient.Transcription.self, from: data)
  }

  public func synthesize(
    text: String,
    voiceID: String,
    modelID: String  // pinned server-side; kept for SpeechBackend conformance
  ) async throws -> Data {
    guard let token = await jws() else { throw ElevenLabsClient.Error.unauthorized }
    let url = baseURL.appendingPathComponent("tts").appendingPathComponent(voiceID)
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
    req.setValue(token, forHTTPHeaderField: "x-atoll-jws")
    req.httpBody = try JSONSerialization.data(withJSONObject: ["text": text])
    let (data, response) = try await session.data(for: req)
    try Self.checkOK(response, body: data)
    return data
  }

  private static func checkOK(_ response: URLResponse, body: Data) throws {
    guard let http = response as? HTTPURLResponse else {
      throw ElevenLabsClient.Error.network("non-HTTP response")
    }
    switch http.statusCode {
    case 200..<300: return
    case 401, 403: throw ElevenLabsClient.Error.unauthorized
    case 429: throw ElevenLabsClient.Error.rateLimit
    default:
      throw ElevenLabsClient.Error.server(
        code: http.statusCode,
        body: String(data: body.prefix(200), encoding: .utf8) ?? ""
      )
    }
  }
}
