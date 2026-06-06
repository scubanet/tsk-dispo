import Foundation
import os
import AtollCore
import Supabase

private let logger = Logger(subsystem: "com.weckherlin.DiveLogPro", category: "AtollAuth")

// ═══════════════════════════════════════
// MARK: - Atoll Session Service
// ═══════════════════════════════════════
//
// Verbindet den bestehenden Apple-Login mit einer Supabase-Session im
// Atoll-Backend (Phase 2, Iteration 1). Nur Session-Aufbau — damit wird
// `auth.uid()` für RLS nutzbar. Der Logbuch-Publisher (Phase 4) setzt
// darauf auf. CloudKit bleibt SSOT des privaten Logbuchs (Entscheidung
// E1 „Hybrid", siehe Deliverable 2026-06-06-divelog-iteration1-plan).

@Observable
@MainActor
final class AtollSessionService {

    static let shared = AtollSessionService()

    /// Liegt eine gültige Supabase-Session vor?
    private(set) var isLinked = false

    /// Letzter Verknüpfungsfehler — für die Anzeige in ProfileEditView.
    private(set) var lastLinkError: String?

    private init() {}

    // ═══════════════════════════════════════
    // MARK: - Bootstrap (App-Start)
    // ═══════════════════════════════════════

    /// Vorhandene Session aus dem lokalen supabase-swift-Storage laden.
    func bootstrap() async {
        do {
            _ = try await SupabaseClient.shared.auth.session
            isLinked = true
            logger.info("Atoll-Session vorhanden")
        } catch {
            isLinked = false
            logger.info("Keine Atoll-Session: \(error.localizedDescription, privacy: .public)")
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Link / Unlink
    // ═══════════════════════════════════════

    /// Nach erfolgreichem Apple-Login: id_token gegen eine Supabase-Session
    /// tauschen. Non-fatal — bei Fehler läuft die App lokal normal weiter.
    func link(credential: AppleCredential, rawNonce: String?) async {
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            lastLinkError = "Apple lieferte kein identityToken."
            logger.error("Link fehlgeschlagen: kein identityToken")
            return
        }
        do {
            _ = try await SupabaseClient.shared.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: rawNonce
                )
            )
            isLinked = true
            lastLinkError = nil
            logger.info("Atoll-Session verknüpft")
        } catch {
            isLinked = false
            lastLinkError = error.localizedDescription
            logger.error("Link fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Supabase-Session lösen. Der Apple-Login bleibt unangetastet.
    func unlink() async {
        try? await SupabaseClient.shared.auth.signOut()
        isLinked = false
        logger.info("Atoll-Session getrennt")
    }
}
