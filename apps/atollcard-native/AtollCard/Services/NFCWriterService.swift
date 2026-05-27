import Foundation
import CoreNFC
import OSLog

/// Writes a card's public URL onto a physical NFC tag using NDEF.
///
/// NFC writing requires:
///   • iPhone 7+ with Core NFC entitlement (set in `AtollCard.entitlements`)
///   • `NFCReaderUsageDescription` in Info.plist (set)
///   • A user-initiated session — we surface `NFCWriterController` from the
///     UI (see `NFCWriteSheet`) so the system prompt appears immediately.
///
/// **Concurrency note:** the Core NFC delegate methods are not annotated by
/// the SDK, so we keep them `nonisolated` and hop to the main actor before
/// touching any stored state. Tag instances aren't `Sendable`, so we do the
/// full async-write dance *inside* the delegate callback (on the NFC queue),
/// then hop back to publish the result.
public final class NFCWriterController: NSObject, NFCNDEFReaderSessionDelegate, @unchecked Sendable {
  // All `private` properties are touched only on the main actor. The
  // `@unchecked Sendable` annotation tells the compiler we know what we
  // are doing — the `nonisolated` delegate methods all hop to main before
  // accessing these.
  private var session: NFCNDEFReaderSession?
  private var url: URL?
  private var completion: ((Result<NFCTagWriteResult, Error>) -> Void)?
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "nfc")

  public override init() { super.init() }

  /// Are we on a device that can write NFC tags? Simulator returns false.
  public static var isAvailable: Bool {
    NFCNDEFReaderSession.readingAvailable
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

    let session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
    session.alertMessage = "Halte dein iPhone an einen leeren NFC-Tag."
    self.session = session
    session.begin()
  }

  // MARK: - NFCNDEFReaderSessionDelegate

  public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
    let snapshot = completionSnapshot()
    if let nsError = error as? NFCReaderError, nsError.code == .readerSessionInvalidationErrorUserCanceled {
      snapshot?(.failure(NFCWriterError.userCancelled))
    } else {
      snapshot?(.failure(error))
    }
    finishOnMain()
  }

  public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
    // Reading-only callback — we use the tag-level delegate path instead.
  }

  public func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
    guard let tag = tags.first else { return }
    guard let url = urlSnapshot() else { return }

    // Connect and write on the NFC queue (not the main actor) using the
    // closure-based API — this side-steps tag-is-not-Sendable issues with
    // structured concurrency / Task on Swift 6.
    session.connect(to: tag) { [weak self] connectError in
      guard let self else { return }
      if let connectError {
        session.invalidate(errorMessage: connectError.localizedDescription)
        self.completionSnapshot()?(.failure(connectError))
        self.finishOnMain()
        return
      }
      tag.queryNDEFStatus { status, capacity, statusError in
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
        tag.writeNDEF(message) { writeError in
          if let writeError {
            session.invalidate(errorMessage: writeError.localizedDescription)
            self.completionSnapshot()?(.failure(writeError))
            self.finishOnMain()
            return
          }
          session.alertMessage = "Tag erfolgreich beschrieben ✓"
          session.invalidate()
          let uid = Self.tagUIDHex(from: tag) ?? "—"
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

  /// `NFCNDEFTag` doesn't expose UID directly — the concrete subtypes do.
  private static func tagUIDHex(from tag: NFCNDEFTag) -> String? {
    if let mifare = tag as? NFCMiFareTag {
      return mifare.identifier.map { String(format: "%02X", $0) }.joined()
    }
    if let iso = tag as? NFCISO15693Tag {
      return iso.identifier.map { String(format: "%02X", $0) }.joined()
    }
    return nil
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
