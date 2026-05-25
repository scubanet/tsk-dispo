import Foundation
import PassKit
import UIKit
import OSLog
import Supabase
import AtollCore

/// Adds a card to Apple Wallet as a generic pass.
///
/// **Important**: pass *signing* requires:
///   1. A Pass Type ID Certificate from the Apple Developer portal
///      (Certificates → Pass Type IDs → register `pass.swiss.atoll.card.persona`).
///   2. The certificate's `.p12` + Apple's `WWDR.pem` need to live on the
///      server (Atoll OS web). The iOS app does **not** sign passes locally —
///      that would leak the certificate.
///   3. The app posts the card metadata to an Edge Function on Atoll OS web
///      (`/api/wallet/pass`) which returns a signed `.pkpass` blob.
///
/// Until that server endpoint exists, `presentPass(...)` falls back to a
/// readable error toast and a TODO in the README. The local pieces — wiring
/// up `PKAddPassesViewController`, decoding the pass into a `PKPass`, and
/// presenting it — are all here and ready for the day signing comes online.
@MainActor
public final class WalletPassService {
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "wallet")

  public init() {}

  /// True if Wallet is available on this device (always true on iPhone,
  /// false on simulator running iOS < 15 — though this guard is mostly
  /// historical at this point).
  public static var isAvailable: Bool {
    PKPassLibrary.isPassLibraryAvailable()
  }

  /// Fetch the `.pkpass` blob from the server and offer it to PassKit.
  ///
  /// The server endpoint is expected to:
  ///   • POST `/api/wallet/pass` with `{ card_id: <uuid> }`
  ///   • return `Content-Type: application/vnd.apple.pkpass`
  ///   • respond with the signed pass binary
  ///
  /// On success we instantiate `PKAddPassesViewController` and let the
  /// caller present it modally.
  public func passViewController(for card: Card) async throws -> PKAddPassesViewController {
    guard Self.isAvailable else { throw WalletPassError.unavailable }

    if Config.useMockData {
      throw WalletPassError.mockMode
    }

    let endpoint = Config.walletPassEndpoint

    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // JWT for owner-auth on the Edge Function
    if let session = try? await SupabaseClient.shared.auth.session {
      request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    } else {
      throw WalletPassError.notAuthenticated
    }

    request.httpBody = try JSONEncoder().encode(["card_id": card.id.uuidString])

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      throw WalletPassError.serverError(status)
    }
    guard !data.isEmpty else { throw WalletPassError.emptyResponse }

    let pass = try PKPass(data: data)
    guard let vc = PKAddPassesViewController(pass: pass) else {
      throw WalletPassError.passInvalid
    }
    return vc
  }
}

public enum WalletPassError: LocalizedError {
  case unavailable
  case mockMode
  case notAuthenticated
  case serverError(Int)
  case emptyResponse
  case passInvalid

  public var errorDescription: String? {
    switch self {
    case .unavailable:        "Apple Wallet ist auf diesem Gerät nicht verfügbar."
    case .mockMode:           "Wallet im Mock-Modus nicht verfügbar — bitte useMockData=false setzen und neu starten."
    case .notAuthenticated:   "Kein gültiges Login — bitte erneut einloggen."
    case .serverError(let s): "Server-Fehler beim Erstellen des Wallet-Passes (Status \(s))."
    case .emptyResponse:      "Server hat keinen Pass geliefert."
    case .passInvalid:        "Pass-Datei ist beschädigt."
    }
  }
}
