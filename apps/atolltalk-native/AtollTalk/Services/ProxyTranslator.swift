import Foundation

/// Pro-tier translator that routes through the Supabase Edge Function instead of
/// calling Anthropic directly — so the Claude key never ships in the app. Sends
/// the StoreKit 2 signed transaction (`jws`) for server-side entitlement check.
struct ProxyTranslator: Translator {
  enum ProxyError: LocalizedError {
    case notEntitled, revoked, expired, rateLimited, http(Int, String), badResponse

    var errorDescription: String? {
      switch self {
      case .notEntitled:
        return String(localized: "Kein gültiges Pro-Abo gefunden. Für echte Pro-Übersetzung ist ein Sandbox-/App-Store-Kauf nötig (lokales StoreKit-Testing wird vom Server nicht akzeptiert).")
      case .revoked:
        return String(localized: "Dein Pro-Abo wurde widerrufen.")
      case .expired:
        return String(localized: "Dein Pro-Abo ist abgelaufen. Bitte erneuere es, um die Pro-Übersetzung zu nutzen.")
      case .rateLimited:
        return String(localized: "Tageslimit für Pro-Übersetzungen erreicht. Bitte versuche es später erneut.")
      case let .http(code, body):
        return String(localized: "Übersetzungs-Server-Fehler \(code): \(body)")
      case .badResponse:
        return String(localized: "Unerwartete Antwort vom Übersetzungs-Server.")
      }
    }

    /// Maps an HTTP status + server `error` code to a user-facing case. The
    /// proxy returns `403 verify_failed|wrong_product|revoked|expired`,
    /// `429 rate_limited`; anything else falls back to the raw status/body.
    static func from(status: Int, serverCode: String?, body: String) -> ProxyError {
      switch (status, serverCode) {
      case (403, "revoked"): return .revoked
      case (403, "expired"): return .expired
      case (403, _):         return .notEntitled // verify_failed, wrong_product, not_entitled
      case (429, _):         return .rateLimited
      default:               return .http(status, body)
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
    guard http.statusCode == 200 else {
      let body = String(data: data, encoding: .utf8) ?? ""
      let serverCode = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["error"] as? String
      throw ProxyError.from(status: http.statusCode, serverCode: serverCode, body: body)
    }
    guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let out = obj["text"] as? String else { throw ProxyError.badResponse }
    return out.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
