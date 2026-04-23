import SwiftUI
import SwiftData
import AuthenticationServices

// ═══════════════════════════════════════
// MARK: - Sign-In Gateway
// ═══════════════════════════════════════
//
// First screen the user ever sees. Until Apple Sign-In completes we don't
// build the onboarding or the main tab view. After a successful sign-in we
// pre-seed the DiverProfile with the name + email Apple handed us — this
// only happens ONCE per Apple-ID (Apple never sends the full name on a
// subsequent sign-in), so we make it count.
//
struct SignInView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var profiles: [DiverProfile]

    @State private var appleSignIn = AppleSignInService.shared
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    @AppStorage("appLanguage") private var appLanguage: String = "en"

    private var isDE: Bool { appLanguage == "de" }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.appAccent.opacity(0.18),
                    Color(uiColor: .systemBackground),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.appAccent.opacity(0.10), Color.clear],
                center: UnitPoint(x: 0.5, y: 0.2),
                startRadius: 40,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                brandBlock
                    .padding(.bottom, 48)

                Spacer()

                signInBlock
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
            }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Brand block

    private var brandBlock: some View {
        VStack(spacing: 20) {
            diveGlyph
                .frame(width: 110, height: 110)

            VStack(spacing: 8) {
                Text("DiveLog Pro")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)

                Text(isDE
                     ? "Dein digitales Tauchlogbuch."
                     : "Your digital dive log.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Sign-in block

    private var signInBlock: some View {
        VStack(spacing: 16) {
            SignInWithAppleButton(
                isLoading: isSigningIn,
                action: { Task { await performSignIn() } }
            )
            .frame(height: 54)

            if let err = errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Text(isDE
                 ? "Apple gibt uns nur deinen Namen und (optional) deine E-Mail. Keine Passwörter, keine Werbung."
                 : "Apple only shares your name and (optionally) email. No passwords, no tracking.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.top, 4)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Sign in handler

    private func performSignIn() async {
        guard !isSigningIn else { return }
        await MainActor.run {
            isSigningIn = true
            errorMessage = nil
        }
        do {
            let cred = try await appleSignIn.signIn()
            await MainActor.run {
                seedProfile(from: cred)
                isSigningIn = false
            }
        } catch {
            await MainActor.run {
                // .canceled → don't bother the user with an error label.
                if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                    errorMessage = nil
                } else {
                    errorMessage = error.localizedDescription
                }
                isSigningIn = false
            }
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Profile seed
    //
    // On the FIRST successful sign-in we create (or update) the single
    // DiverProfile with the name + email Apple supplied. This runs before
    // the onboarding, so the OnboardingView's identity step will find the
    // fields pre-filled.
    //
    private func seedProfile(from cred: AppleCredential) {
        let profile: DiverProfile
        if let existing = profiles.first {
            profile = existing
        } else {
            let new = DiverProfile()
            ctx.insert(new)
            profile = new
        }

        profile.appleUserID = cred.userID

        if let name = cred.fullName, !name.isEmpty,
           profile.name.trimmingCharacters(in: .whitespaces).isEmpty {
            profile.name = name
        }

        if let email = cred.email, !email.isEmpty,
           profile.email.trimmingCharacters(in: .whitespaces).isEmpty {
            profile.email = email
        }

        try? ctx.save()
    }

    // ═══════════════════════════════════════
    // MARK: - Brand glyph

    private var diveGlyph: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let lensH = w * 0.55
            let lensW = w * 0.42
            let gap: CGFloat = 2
            ZStack {
                RoundedRectangle(cornerRadius: lensW * 0.32)
                    .stroke(Color.appAccent, lineWidth: w * 0.06)
                    .frame(width: lensW, height: lensH)
                    .offset(x: -(lensW + gap) / 2)
                RoundedRectangle(cornerRadius: lensW * 0.32)
                    .stroke(Color.appAccent, lineWidth: w * 0.06)
                    .frame(width: lensW, height: lensH)
                    .offset(x: (lensW + gap) / 2)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.appAccent)
                    .frame(width: gap + 6, height: lensH * 0.35)
                Circle()
                    .fill(Color.appEmphasis)
                    .frame(width: w * 0.04, height: w * 0.04)
            }
            .frame(width: w, height: geo.size.height)
        }
    }
}

// ═══════════════════════════════════════
// MARK: - Native Sign-In-with-Apple button
// ═══════════════════════════════════════
//
// Thin SwiftUI wrapper around Apple's UIKit ASAuthorizationAppleIDButton.
// We use the UIKit variant (not Apple's SwiftUI SignInWithAppleButton) so
// we can fully control the action + loading state without fighting the
// ASAuthorizationController lifecycle.
//
struct SignInWithAppleButton: UIViewRepresentable {
    let isLoading: Bool
    let action: () -> Void

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        let button = ASAuthorizationAppleIDButton(
            type: .signIn,
            style: traitStyle()
        )
        button.cornerRadius = DSRadius.l
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(context.coordinator,
                         action: #selector(Coordinator.tapped),
                         for: .touchUpInside)
        context.coordinator.button = button

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        spinner.color = .white
        context.coordinator.spinner = spinner

        container.addSubview(button)
        container.addSubview(spinner)

        // `ASAuthorizationAppleIDButton` has an internal required-priority
        // max-width constraint (~375pt) baked in by Apple. If we pin our
        // button's leading/trailing to a wider container we get the runtime
        // "width <= 375 conflicts with width = 384" warning.
        //
        // Fix: centre the button, allow it to match container width at
        // defaultHigh priority (so it still fills narrow phones), but let
        // Apple's internal cap win on wider layouts (iPad, landscape, split
        // view). Inequality constraints keep the button from spilling out.
        let widthMatch = button.widthAnchor.constraint(
            equalTo: container.widthAnchor
        )
        widthMatch.priority = .defaultHigh

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            button.leadingAnchor.constraint(
                greaterThanOrEqualTo: container.leadingAnchor
            ),
            button.trailingAnchor.constraint(
                lessThanOrEqualTo: container.trailingAnchor
            ),
            widthMatch,

            // Spinner sits inside the button's trailing edge, not the
            // container's — otherwise it drifts off on wide layouts where
            // the button is capped at 375pt and centred.
            spinner.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            spinner.trailingAnchor.constraint(
                equalTo: button.trailingAnchor,
                constant: -18
            ),
        ])

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.action = action
        if isLoading {
            context.coordinator.spinner?.startAnimating()
            context.coordinator.button?.isUserInteractionEnabled = false
            context.coordinator.button?.alpha = 0.75
        } else {
            context.coordinator.spinner?.stopAnimating()
            context.coordinator.button?.isUserInteractionEnabled = true
            context.coordinator.button?.alpha = 1.0
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    /// Match Apple's button to the current interface style.
    private func traitStyle() -> ASAuthorizationAppleIDButton.Style {
        UITraitCollection.current.userInterfaceStyle == .dark ? .white : .black
    }

    final class Coordinator {
        var action: () -> Void
        weak var button: ASAuthorizationAppleIDButton?
        weak var spinner: UIActivityIndicatorView?

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func tapped() {
            action()
        }
    }
}

#Preview {
    SignInView()
        .modelContainer(for: [Dive.self, DiverProfile.self, DiveSite.self, Buddy.self, DiveSignature.self], inMemory: true)
}
