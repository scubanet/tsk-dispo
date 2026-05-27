import Foundation
import UIKit
import Supabase
import AtollCore
import OSLog

/// Upload + persist a portrait photo for the signed-in user's contact row.
///
/// **Flow** (called from `SettingsView` after a `PhotosPicker` selection):
///   1. Resolve the current `auth_user_id` from the Supabase session.
///   2. Look up the user's `contact_id` via the `contact_instructor`
///      sidecar table (same lookup the push-fan-out function uses).
///   3. Resize the picked image to a square 512×512 JPEG at 0.85 quality
///      (keeps the upload <100 KB while still looking sharp at retina sizes).
///   4. Upload to the public-read `contact-avatars` Storage bucket at
///      `<contact_id>.jpg` with `upsert: true` so re-uploads overwrite.
///   5. Build the public CDN URL and PATCH `contacts.avatar_url`.
///   6. Append a `?v=<unix-ts>` cache-buster so the new file is fetched
///      immediately (Supabase's public CDN caches aggressively).
///
/// **Bucket + RLS:** set up by migration 0101. The Storage policy lets
/// authenticated users write only their own `<contact_id>.jpg`, so a
/// compromised JWT can't replace someone else's portrait.
///
/// **iOS app rendering:** writing the URL is enough for the public page
/// (`/c/<slug>`) to render the photo immediately. The native iOS BizCard
/// still shows initials in v1 — adding photo rendering to the in-app
/// avatar is tracked separately (would need a `ProfileStore` or threading
/// `avatar_url` through MockSeed.dominik on launch).
@MainActor
public final class AvatarUploadService {
  public static let shared = AvatarUploadService()
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "avatar")

  private init() {}

  public enum UploadError: Error, LocalizedError {
    case notAuthenticated
    case contactNotLinked
    case imageEncodingFailed

    public var errorDescription: String? {
      switch self {
      case .notAuthenticated:    "Du bist nicht eingeloggt."
      case .contactNotLinked:    "Kein Kontakt mit deinem Account verknüpft."
      case .imageEncodingFailed: "Bild konnte nicht in JPEG gewandelt werden."
      }
    }
  }

  /// Returns the new public URL (cache-busted) on success.
  @discardableResult
  public func upload(image: UIImage) async throws -> String {
    let client = SupabaseClient.shared

    // 1. Auth.
    let session = try await client.auth.session
    let authUserId = session.user.id

    // 2. Contact id. Decode into `[Sidecar]` and take .first — same pattern
    // SupabaseCardRepository uses for single-row lookups.
    struct Sidecar: Decodable { let contact_id: String }
    let sidecars: [Sidecar] = try await client
      .from("contact_instructor")
      .select("contact_id")
      .eq("auth_user_id", value: authUserId.uuidString)
      .limit(1)
      .execute()
      .value
    guard let contactId = sidecars.first?.contact_id else {
      throw UploadError.contactNotLinked
    }

    // 3. Square-crop + resize + JPEG-encode.
    let squared  = image.squareCropped()
    let resized  = squared.resized(to: CGSize(width: 512, height: 512))
    guard let jpegData = resized.jpegData(compressionQuality: 0.85) else {
      throw UploadError.imageEncodingFailed
    }
    Self.logger.debug("Encoded JPEG: \(jpegData.count, privacy: .public) bytes")

    // 4. Upload.
    let path = "\(contactId).jpg"
    try await client.storage
      .from("contact-avatars")
      .upload(
        path,
        data: jpegData,
        options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
      )

    // 5. Public URL + cache-buster.
    let baseUrl = try client.storage
      .from("contact-avatars")
      .getPublicURL(path: path)
      .absoluteString
    let publicUrl = "\(baseUrl)?v=\(Int(Date().timeIntervalSince1970))"

    // 6. PATCH contacts.avatar_url.
    try await client
      .from("contacts")
      .update(["avatar_url": publicUrl])
      .eq("id", value: contactId)
      .execute()

    Self.logger.debug("Avatar persisted: \(publicUrl, privacy: .public)")
    return publicUrl
  }

  /// Reads the current portrait URL for the signed-in user's contact,
  /// or `nil` if no photo is stored yet. Used by SettingsView to render
  /// the "current state" preview when the sheet first opens.
  public func fetchCurrentAvatarUrl() async throws -> URL? {
    let client = SupabaseClient.shared
    let session = try await client.auth.session

    struct Sidecar: Decodable { let contact_id: String }
    let sidecars: [Sidecar] = try await client
      .from("contact_instructor")
      .select("contact_id")
      .eq("auth_user_id", value: session.user.id.uuidString)
      .limit(1)
      .execute()
      .value
    guard let contactId = sidecars.first?.contact_id else { return nil }

    struct ContactRow: Decodable { let avatar_url: String? }
    let rows: [ContactRow] = try await client
      .from("contacts")
      .select("avatar_url")
      .eq("id", value: contactId)
      .limit(1)
      .execute()
      .value

    return rows.first?.avatar_url.flatMap(URL.init(string:))
  }
}

// MARK: - UIImage helpers

private extension UIImage {
  /// Centre-crops to a square using the shorter side. Cheap — no redraw.
  func squareCropped() -> UIImage {
    let side = min(size.width, size.height)
    let originX = (size.width  - side) / 2
    let originY = (size.height - side) / 2
    let cropRect = CGRect(x: originX * scale, y: originY * scale,
                          width: side * scale, height: side * scale)
    guard let cg = cgImage?.cropping(to: cropRect) else { return self }
    return UIImage(cgImage: cg, scale: scale, orientation: imageOrientation)
  }

  /// Re-renders at a target size. Uses UIGraphicsImageRenderer so the
  /// result respects the device pixel scale (no fuzzy upscale).
  func resized(to target: CGSize) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: target)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: target))
    }
  }
}
