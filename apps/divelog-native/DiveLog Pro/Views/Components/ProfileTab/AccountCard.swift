import SwiftUI
import SwiftData

/// Account information card: Apple-Sign-In status, sign-out, delete-account.
/// Destructive actions are confirmed via ProfileTab's @State-driven dialogs;
/// this card just exposes button-tap callbacks. The actual sign-out and
/// delete-account logic stays in ProfileTab because it mutates ModelContext
/// and the AppleSignInService singleton.
struct AccountCard: View {
    let profile: DiverProfile?
    let appleSignIn: AppleSignInService
    let onSignOutTap: () -> Void
    let onDeleteAccountTap: () -> Void

    var body: some View {
        VStack(spacing: 1) {
            // Apple identity row — shows email as subtitle
            appleIdentityRow

            // Sign out
            Button {
                onSignOutTap()
            } label: {
                settingsRow(icon: "rectangle.portrait.and.arrow.right",
                            label: L10n.currentLanguage == "de" ? "Abmelden" : "Sign Out") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            // Delete account (Apple Review mandatory)
            Button {
                onDeleteAccountTap()
            } label: {
                settingsRow(icon: "trash.fill",
                            label: L10n.currentLanguage == "de" ? "Account löschen" : "Delete Account") {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(Color.appEmphasis)
            }
            .buttonStyle(.plain)
        }
    }

    // ─── Display-only helpers ────────────────────────────────────────────────

    /// Two-line identity row — primary "Angemeldet mit Apple" with the email
    /// as subtitle underneath. Custom-built because `settingsRow` expects a
    /// single-line label; this variant gives the account section the
    /// classic iOS identity-header feel.
    private var appleIdentityRow: some View {
        HStack(spacing: DSSpacing.m + 2) {
            Image(systemName: "apple.logo")
                .font(.system(size: 16))
                .foregroundStyle(Color.appAccent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.currentLanguage == "de"
                     ? "Angemeldet mit Apple"
                     : "Signed in with Apple")
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)

                if let email = accountEmail {
                    HStack(spacing: 6) {
                        Text(email)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        if isPrivateRelayEmail {
                            Text(L10n.currentLanguage == "de" ? "PRIVAT-RELAY" : "PRIVATE RELAY")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.5)
                                .foregroundStyle(Color.appAccent)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule().fill(Color.appAccent.opacity(0.12))
                                )
                        }
                    }
                } else {
                    Text(L10n.currentLanguage == "de"
                         ? "E-Mail nicht geteilt"
                         : "Email not shared")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.appSuccess)
        }
        .padding(DSSpacing.m + 2)
        .solidCard(cornerRadius: DSRadius.m)
    }

    /// Returns the best available email string: Keychain-stored email first,
    /// then profile.email as a fallback. Apple only provides the email on the
    /// initial auth — so on a second device with the same Apple ID, Keychain
    /// is empty and this fallback kicks in.
    private var accountEmail: String? {
        if let keychainEmail = appleSignIn.currentEmail,
           !keychainEmail.trimmingCharacters(in: .whitespaces).isEmpty {
            return keychainEmail
        }
        if let profileEmail = profile?.email,
           !profileEmail.trimmingCharacters(in: .whitespaces).isEmpty {
            return profileEmail
        }
        return nil
    }

    /// Apple's private-relay addresses look like `xxx@privaterelay.appleid.com`.
    /// We surface these with a small "Privat-Relay" hint so the user isn't
    /// surprised by an unfamiliar-looking address.
    private var isPrivateRelayEmail: Bool {
        guard let email = accountEmail else { return false }
        return email.lowercased().hasSuffix("@privaterelay.appleid.com")
    }
}
