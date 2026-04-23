import Foundation
import CloudKit
import UIKit

// ═══════════════════════════════════════
// MARK: - Remote Signature Service
// ═══════════════════════════════════════
//
// Uses the **public** CloudKit database so two different Apple IDs (owner and
// buddy) can exchange a pending signature.
//
// Record types (create these once in the CloudKit Dashboard → Schema →
// Record Types for container `iCloud.com.weckherlin.DiveLogPro`):
//
//   PendingSignature
//     • token          String  (Queryable, Sortable)
//     • diveNumber     Int(64)
//     • siteName       String
//     • siteLocation   String
//     • diveDate       Date/Time
//     • maxDepth       Double
//     • totalTime      Int(64)
//     • ownerName      String
//     • createdAt      Date/Time
//     • expiresAt      Date/Time
//
//   CompletedSignature
//     • token          String  (Queryable)
//     • buddyName      String
//     • buddyPadi      String
//     • signaturePNG   Asset
//     • signedAt       Date/Time
//

enum RemoteSignatureService {

    // MARK: - Types

    struct PendingPayload {
        let token: String
        let diveNumber: Int
        let siteName: String
        let siteLocation: String
        let diveDate: Date
        let maxDepth: Double
        let totalTime: Int
        let ownerName: String
        let expiresAt: Date
    }

    struct CompletedPayload {
        let token: String
        let buddyName: String
        let buddyPadi: String
        let signaturePNGData: Data
        let signedAt: Date
    }

    enum ServiceError: LocalizedError {
        case notFound
        case expired
        case cloudKit(Error)

        var errorDescription: String? {
            switch self {
            case .notFound:        return "Signature link not found."
            case .expired:         return "This signature link has expired."
            case .cloudKit(let e): return e.localizedDescription
            }
        }
    }

    // MARK: - Constants

    private static let container = CKContainer(identifier: "iCloud.com.weckherlin.DiveLogPro")
    private static var db: CKDatabase { container.publicCloudDatabase }

    static let expiryDays = 7

    // MARK: - URL helpers

    /// Build the `divelogpro://remote-sign?token=…` link.
    static func signingURL(for token: String) -> URL {
        var comps = URLComponents()
        comps.scheme = "divelogpro"
        comps.host   = "remote-sign"
        comps.queryItems = [URLQueryItem(name: "token", value: token)]
        return comps.url!
    }

    /// Parse a URL back into a token. Returns nil if the URL does not match.
    static func token(fromURL url: URL) -> String? {
        guard url.scheme == "divelogpro",
              url.host == "remote-sign",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = comps.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty
        else { return nil }
        return token
    }

    // MARK: - Owner flow: create pending

    static func createPending(_ payload: PendingPayload) async throws {
        let rec = CKRecord(recordType: "PendingSignature")
        rec["token"]        = payload.token        as CKRecordValue
        rec["diveNumber"]   = payload.diveNumber   as CKRecordValue
        rec["siteName"]     = payload.siteName     as CKRecordValue
        rec["siteLocation"] = payload.siteLocation as CKRecordValue
        rec["diveDate"]     = payload.diveDate     as CKRecordValue
        rec["maxDepth"]     = payload.maxDepth     as CKRecordValue
        rec["totalTime"]    = payload.totalTime    as CKRecordValue
        rec["ownerName"]    = payload.ownerName    as CKRecordValue
        rec["createdAt"]    = Date()               as CKRecordValue
        rec["expiresAt"]    = payload.expiresAt    as CKRecordValue

        do {
            _ = try await db.save(rec)
        } catch {
            throw ServiceError.cloudKit(error)
        }
    }

    // MARK: - Buddy flow: fetch pending

    static func fetchPending(token: String) async throws -> PendingPayload {
        let predicate = NSPredicate(format: "token == %@", token)
        let query = CKQuery(recordType: "PendingSignature", predicate: predicate)

        do {
            let (matches, _) = try await db.records(matching: query, resultsLimit: 1)
            guard let first = matches.first else {
                throw ServiceError.notFound
            }
            let rec = try first.1.get()

            let expires = rec["expiresAt"] as? Date ?? .distantPast
            if expires < .now {
                throw ServiceError.expired
            }

            return PendingPayload(
                token:        rec["token"]        as? String ?? token,
                diveNumber:   rec["diveNumber"]   as? Int    ?? 0,
                siteName:     rec["siteName"]     as? String ?? "",
                siteLocation: rec["siteLocation"] as? String ?? "",
                diveDate:     rec["diveDate"]     as? Date   ?? .now,
                maxDepth:     rec["maxDepth"]     as? Double ?? 0,
                totalTime:    rec["totalTime"]    as? Int    ?? 0,
                ownerName:    rec["ownerName"]    as? String ?? "",
                expiresAt:    expires
            )
        } catch let err as ServiceError {
            throw err
        } catch {
            throw ServiceError.cloudKit(error)
        }
    }

    // MARK: - Buddy flow: save completed

    static func saveCompleted(_ payload: CompletedPayload) async throws {
        // Write the PNG to a temp file — CKAsset needs a URL.
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("sig-\(UUID().uuidString).png")
        try payload.signaturePNGData.write(to: tmp)

        let rec = CKRecord(recordType: "CompletedSignature")
        rec["token"]        = payload.token       as CKRecordValue
        rec["buddyName"]    = payload.buddyName   as CKRecordValue
        rec["buddyPadi"]    = payload.buddyPadi   as CKRecordValue
        rec["signaturePNG"] = CKAsset(fileURL: tmp)
        rec["signedAt"]     = payload.signedAt    as CKRecordValue

        do {
            _ = try await db.save(rec)
        } catch {
            throw ServiceError.cloudKit(error)
        }

        try? FileManager.default.removeItem(at: tmp)
    }

    // MARK: - Owner flow: poll for completed

    /// Returns any CompletedSignature records whose token is in the given set.
    /// Used by SignTab to import fresh signatures back into SwiftData.
    static func fetchCompleted(tokens: [String]) async throws -> [CompletedPayload] {
        guard !tokens.isEmpty else { return [] }

        let predicate = NSPredicate(format: "token IN %@", tokens)
        let query = CKQuery(recordType: "CompletedSignature", predicate: predicate)

        do {
            let (matches, _) = try await db.records(matching: query, resultsLimit: 50)

            var results: [CompletedPayload] = []
            for (_, res) in matches {
                guard let rec = try? res.get() else { continue }

                let token = rec["token"]     as? String ?? ""
                let name  = rec["buddyName"] as? String ?? ""
                let padi  = rec["buddyPadi"] as? String ?? ""
                let when  = rec["signedAt"]  as? Date   ?? .now

                var png = Data()
                if let asset = rec["signaturePNG"] as? CKAsset,
                   let url = asset.fileURL,
                   let data = try? Data(contentsOf: url) {
                    png = data
                }

                results.append(CompletedPayload(
                    token: token, buddyName: name, buddyPadi: padi,
                    signaturePNGData: png, signedAt: when
                ))
            }
            return results
        } catch {
            throw ServiceError.cloudKit(error)
        }
    }

    // MARK: - Cleanup

    /// Deletes pending + completed records for a token once the signature has
    /// been imported into the owner's local store.
    static func cleanup(token: String) async {
        let predicate = NSPredicate(format: "token == %@", token)
        for type in ["PendingSignature", "CompletedSignature"] {
            let q = CKQuery(recordType: type, predicate: predicate)
            if let (matches, _) = try? await db.records(matching: q, resultsLimit: 10) {
                for (id, _) in matches {
                    _ = try? await db.deleteRecord(withID: id)
                }
            }
        }
    }
}
