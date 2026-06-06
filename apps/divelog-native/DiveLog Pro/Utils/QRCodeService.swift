import Foundation
import UIKit
import CoreImage.CIFilterBuiltins

// ═══════════════════════════════════════
// MARK: - QR Code Service
// ═══════════════════════════════════════
//
// Generates QR codes from a DiverProfile identity, and parses scanned strings
// back into an Identity. Custom URL scheme:
//   divelogpro://identity?name=…&padi=…&level=…
//
// QR is an *identity-transfer shortcut* — it pre-fills the buddy's details
// before they sign with their finger. The finger signature remains the proof.
// `qrHash` lets us flag signatures that originated from a scanned identity.
//
enum QRCodeService {

    // ─── Identity payload ────────────────

    struct Identity: Equatable {
        let name: String
        let padiNumber: String
        let certLevel: String

        var payloadString: String {
            var comps = URLComponents()
            comps.scheme = "divelogpro"
            comps.host = "identity"
            comps.queryItems = [
                URLQueryItem(name: "name",  value: name),
                URLQueryItem(name: "padi",  value: padiNumber),
                URLQueryItem(name: "level", value: certLevel),
            ]
            return comps.url?.absoluteString ?? ""
        }

        /// Stable fingerprint stored in DiveSignature.qrHash.
        /// Not cryptographic — just dedup/audit.
        var fingerprint: String {
            "\(name)|\(padiNumber)|\(certLevel)".lowercased()
        }
    }

    // ─── Generator ───────────────────────

    /// Produces a high-contrast QR image. Returns nil if generation fails.
    static func generate(_ identity: Identity, size: CGFloat = 512) -> UIImage? {
        let ctx = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(identity.payloadString.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }

        let scale = size / max(output.extent.width, 1)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    // ─── Parser ──────────────────────────

    /// Parses a scanned string into an Identity. Returns nil if not a valid payload.
    static func parseIdentity(from raw: String) -> Identity? {
        guard let url = URL(string: raw),
              url.scheme == "divelogpro",
              url.host == "identity"
        else { return nil }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let dict = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let v = item.value else { return nil }
            return (item.name, v)
        })

        let name  = (dict["name"]  ?? "").trimmingCharacters(in: .whitespaces)
        let padi  = (dict["padi"]  ?? "").trimmingCharacters(in: .whitespaces)
        let level = (dict["level"] ?? "OWD").trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty else { return nil }
        return Identity(name: name, padiNumber: padi, certLevel: level)
    }
}
