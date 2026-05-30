import Foundation
@preconcurrency import CoreNFC
import OSLog

/// Writes a card's public URL onto a physical NFC tag using NDEF.
///
/// NFC writing requires:
///   • iPhone 7+ with Core NFC entitlement (set in `AtollCard.entitlements`)
///   • `NFCReaderUsageDescription` in Info.plist (set)
///   • A user-initiated session — we surface `NFCWriterController` from the
///     UI (see `NFCWriteSheet`) so the system prompt appears immediately.
///
/// Uses `NFCTagReaderSession` (entitlement format `TAG`). The legacy
/// `NFCNDEFReaderSession` / `NDEF` entitlement is no longer accepted by App
/// Store Connect on iOS 26 SDKs.
///
/// **Concurrency note:** the Core NFC delegate methods are not annotated by
/// the SDK, so we keep them `nonisolated` and hop to the main actor before
/// touching any stored state. Tag instances aren't `Sendable`, so we do the
/// full async-write dance *inside* the delegate callback (on the NFC queue),
/// then hop back to publish the result.
public final class NFCWriterController: NSObject, NFCTagReaderSessionDelegate, @unchecked Sendable {
  // All `private` properties are touched only on the main actor. The
  // `@unchecked Sendable` annotation tells the compiler we know what we
  // are doing — the `nonisolated` delegate methods all hop to main before
  // accessing these.
  private var session: NFCTagReaderSession?
  private var url: URL?
  private var completion: ((Result<NFCTagWriteResult, Error>) -> Void)?
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "nfc")

  public override init() { super.init() }

  /// Are we on a device that can write NFC tags? Simulator returns false.
  public static var isAvailable: Bool {
    NFCTagReaderSession.readingAvailable
  }

  /// Start a write session. The completion handler is invoked exactly once
  /// on the main actor; the session terminates itself afterwards.
  @MainActor
  public func write(url: URL, completion: @escaping @MainActor (Result<NFCTagWriteResult, Error>) -> Void) {
    guard Self.isAvailable else {
      completion(.failure(NFCWriterError.unavailable))
      return
    }
    self.url = url
    self.completion = { result in Task { @MainActor in completion(result) } }

    let session = NFCTagReaderSession(
      pollingOption: [.iso14443, .iso15693, .iso18092],
      delegate: self,
      queue: nil
    )
    session?.alertMessage = "Halte dein iPhone an einen leeren NFC-Tag."
    self.session = session
    session?.begin()
  }

  // MARK: - NFCTagReaderSessionDelegate

  public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

  public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    let snapshot = completionSnapshot()
    if let nsError = error as? NFCReaderError, nsError.code == .readerSessionInvalidationErrorUserCanceled {
      snapshot?(.failure(NFCWriterError.userCancelled))
    } else {
      snapshot?(.failure(error))
    }
    finishOnMain()
  }

  public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [CoreNFC.NFCTag]) {
    guard let firstTag = tags.first else { return }
    guard let url = urlSnapshot() else { return }

    // Connect and write on the NFC queue (not the main actor) using the
    // closure-based API — this side-steps tag-is-not-Sendable issues with
    // structured concurrency / Task on Swift 6.
    session.connect(to: firstTag) { [weak self] connectError in
      guard let self else { return }
      if let connectError {
        session.invalidate(errorMessage: connectError.localizedDescription)
        self.completionSnapshot()?(.failure(connectError))
        self.finishOnMain()
        return
      }
      guard let ndefTag = Self.ndefTag(from: firstTag) else {
        session.invalidate(errorMessage: NFCWriterError.notSupported.localizedDescription)
        self.completionSnapshot()?(.failure(NFCWriterError.notSupported))
        self.finishOnMain()
        return
      }
      ndefTag.queryNDEFStatus { status, capacity, statusError in
        if let statusError {
          session.invalidate(errorMessage: statusError.localizedDescription)
          self.completionSnapshot()?(.failure(statusError))
          self.finishOnMain()
          return
        }
        guard status != .notSupported else {
          session.invalidate(errorMessage: NFCWriterError.notSupported.localizedDescription)
          self.completionSnapshot()?(.failure(NFCWriterError.notSupported))
          self.finishOnMain()
          return
        }
        guard status != .readOnly else {
          session.invalidate(errorMessage: NFCWriterError.readOnly.localizedDescription)
          self.completionSnapshot()?(.failure(NFCWriterError.readOnly))
          self.finishOnMain()
          return
        }
        guard let payload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url) else {
          session.invalidate(errorMessage: NFCWriterError.payloadEncoding.localizedDescription)
          self.completionSnapshot()?(.failure(NFCWriterError.payloadEncoding))
          self.finishOnMain()
          return
        }
        let message = NFCNDEFMessage(records: [payload])
        guard message.length <= capacity else {
          let err = NFCWriterError.payloadTooLarge(capacity)
          session.invalidate(errorMessage: err.localizedDescription)
          self.completionSnapshot()?(.failure(err))
          self.finishOnMain()
          return
        }
        ndefTag.writeNDEF(message) { writeError in
          if let writeError {
            session.invalidate(errorMessage: writeError.localizedDescription)
            self.completionSnapshot()?(.failure(writeError))
            self.finishOnMain()
            return
          }
          session.alertMessage = "Tag erfolgreich beschrieben ✓"
          session.invalidate()
          let uid = Self.tagUIDHex(from: firstTag) ?? "—"
          self.completionSnapshot()?(.success(NFCTagWriteResult(tagUID: uid, capacity: capacity)))
          self.finishOnMain()
        }
      }
    }
  }

  // MARK: - Snapshots (read from any queue, mutate state via main hop)

  private func urlSnapshot() -> URL? {
    // Reading a single optional reference is safe enough; we never write it
    // off the main actor.
    self.url
  }

  private func completionSnapshot() -> ((Result<NFCTagWriteResult, Error>) -> Void)? {
    self.completion
  }

  private func finishOnMain() {
    Task { @MainActor [weak self] in
      self?.session = nil
      self?.url = nil
      self?.completion = nil
    }
  }

  /// Resolve the NDEF-capable view of a concrete `NFCTag` enum case.
  private static func ndefTag(from tag: CoreNFC.NFCTag) -> NFCNDEFTag? {
    switch tag {
    case .miFare(let t):   return t
    case .iso15693(let t): return t
    case .iso7816(let t):  return t
    case .feliCa(let t):   return t
    @unknown default:      return nil
    }
  }

  /// Extract the tag UID as hex — concrete subtypes expose different fields.
  private static func tagUIDHex(from tag: CoreNFC.NFCTag) -> String? {
    switch tag {
    case .miFare(let t):   return t.identifier.map { String(format: "%02X", $0) }.joined()
    case .iso15693(let t): return t.identifier.map { String(format: "%02X", $0) }.joined()
    case .iso7816(let t):  return t.identifier.map { String(format: "%02X", $0) }.joined()
    case .feliCa(let t):   return t.currentIDm.map { String(format: "%02X", $0) }.joined()
    @unknown default:      return nil
    }
  }
}

public struct NFCTagWriteResult: Sendable {
  public let tagUID: String
  public let capacity: Int
}

public enum NFCWriterError: LocalizedError {
  case unavailable
  case notSupported
  case readOnly
  case payloadTooLarge(Int)
  case payloadEncoding
  case userCancelled

  public var errorDescription: String? {
    switch self {
    case .unavailable:        "NFC ist auf diesem Gerät nicht verfügbar."
    case .notSupported:       "Dieser Tag unterstützt NDEF nicht."
    case .readOnly:           "Der Tag ist schreibgeschützt."
    case .payloadTooLarge(let cap): "Die URL passt nicht (Tag-Kapazität: \(cap) Bytes)."
    case .payloadEncoding:    "Konnte die URL nicht in eine NDEF-Nachricht packen."
    case .userCancelled:      "Vorgang abgebrochen."
    }
  }
}
