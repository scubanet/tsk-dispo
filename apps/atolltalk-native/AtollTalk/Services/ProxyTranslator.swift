import Foundation

/// Pro-tier translator that routes through the Supabase Edge Function instead of
/// calling Anthropic directly — so the Claude key never ships in the app. Sends
/// the StoreKit 2 signed transaction (`jws`) for server-side entitlement check.
struct ProxyTranslator: Translator {
  enum ProxyError: LocalizedError {
    case notEntitled, http(Int), badResponse

    var errorDescription: String? {
      switch self {
      case .notEntitled:
        return String(localized: "Kein gültiges Pro-Abo gefunden. Für echte Pro-Übersetzung ist ein Sandbox-/App-Store-Kauf nötig (lokales StoreKit-Testing wird vom Server nicht akzeptiert).")
      case let .http(code):
        return String(localized: "Übersetzungs-Server antwortete mit Fehler \(code).")
      case .badResponse:
        return String(localized: "Unerwartete Antwort vom Übersetzungs-Server.")
      }
    }
  }

  let endpoint: URL
  let model: String
  let jws: @Sendable () async -> String?
  let session: URLSession

  init(endpoint: URL = Config.translateProxyURL,
       model: String = Config.defaultModel,
       jws: @escaping @Sendable () async -> String?,
       session: URLSession = .shared) {
    self.endpoint = endpoint
    self.model = model
    self.jws = jws
    self.session = session
  }

  func translate(_ text: String, from source: AppLanguage, to target: AppLanguage,
                 context: String, glossary: String) async throws -> String {
    guard let token = await jws() else { throw ProxyError.notEntitled }
    var req = URLRequest(url: endpoint)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
    req.httpBody = try JSONSerialization.data(withJSONObject: [
      "text": text,
      "source": source.rawValue,
      "target": target.displayName,
      "context": context,
      "glossary": glossary,
      "model": model,
      "jws": token,
    ])

    let (data, response) = try await session.data(for: req)
    guard let http = response as? HTTPURLResponse else { throw ProxyError.badResponse }
    guard http.statusCode == 200 else { throw ProxyError.http(http.statusCode) }
    guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let out = obj["text"] as? String else { throw ProxyError.badResponse }
    return out.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
