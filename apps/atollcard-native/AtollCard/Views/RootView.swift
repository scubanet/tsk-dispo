import SwiftUI
import AtollCore

/// Top-level container. Hosts the tab-pill bar at the top + the floating
/// action bar at the bottom, and routes between Cards / Leads / Analytics /
/// Settings inside.
///
/// Unlike a classic `TabView`, we drive the active surface from a single
/// `@State` enum because the floating action bar already serves as the
/// bottom-of-screen anchor. A `TabView` would add a second one.
struct RootView: View {
  @Environment(AuthState.self)        private var auth
  @Environment(CardStore.self)        private var cardStore
  @Environment(LeadStore.self)        private var leadStore
  @Environment(AnalyticsStore.self)   private var analyticsStore
  @Environment(ReachabilityMonitor.self) private var reach

  @State private var route: Route = .cards
  @State private var showSettings = false
  @State private var showNewCardEditor = false

  enum Route: String, CaseIterable, Identifiable {
    case cards, leads, analytics
    var id: String { rawValue }
  }

  var body: some View {
    // `@Bindable` here so we can drive the Fullscreen-QR sheet off
    // `cardStore.presentingFullscreenQR` — set by the Lock-Screen widget
    // deep-link handler in `AtollCardApp`.
    @Bindable var cardStoreBindable = cardStore

    Group {
      // Im Mock-Mode überspringen wir den Auth-Flow komplett — der Magic-
      // Link-Round-Trip braucht ein konfiguriertes Supabase + Custom-URL-
      // Scheme-Whitelist und ist hier nur Lärm. Sobald `Config.useMockData
      // = false`, läuft der echte Flow.
      if Config.useMockData {
        signedInBody
      } else {
        switch auth.status {
        case .loading:    LoadingView()
        case .signedOut:  SignedOutView()
        case .signedIn:   signedInBody
        }
      }
    }
    .safeAreaInset(edge: .top, spacing: 0) {
      if !reach.isConnected {
        OfflineBanner()
      }
    }
    .sheet(isPresented: $showSettings) {
      SettingsView()
    }
    .sheet(isPresented: $showNewCardEditor) {
      CardEditorSheet(card: nil)
    }
    // Widget deep-link target: when `cardStore.presentingFullscreenQR` is set
    // (by the `atollcard://card/<slug>/qr` handler), this sheet presents the
    // Fullscreen-QR view with brightness-boost. AtollCard has no centralised
    // persons store today, so we follow the same convention as the rest of
    // the surface and reach for `MockSeed.dominik` (Phase B match).
    .sheet(item: $cardStoreBindable.presentingFullscreenQR) { card in
      FullscreenQRView(card: card, person: MockSeed.dominik)
    }
  }

  @ViewBuilder
  private var signedInBody: some View {
    ZStack(alignment: .bottom) {
      Color.cardPageBackground.ignoresSafeArea()

      Group {
        switch route {
        case .cards:     CardsView()
        case .leads:     LeadsView()
        case .analytics: AnalyticsView()
        }
      }
      .padding(.bottom, 92)   // reserve space for the FAB

      FloatingActionBar(
        personInitials: MockSeed.dominik.initials,
        personName: MockSeed.dominik.firstName,
        personColorHex: MockSeed.dominik.avatarColorHex,
        onMenuTap:   { showSettings = true },
        onAvatarTap: { showSettings = true },
        onSearchTap: { route = cycleRoute() },   // until we wire global search
        onAddTap:    { showNewCardEditor = true }
      )
      .padding(.bottom, 16)
    }
  }

  /// Cycles Cards → Leads → Analytics → Cards. Used by the FAB search button
  /// for now as a quick navigation crutch until a proper search UI exists.
  private func cycleRoute() -> Route {
    let all = Route.allCases
    let idx = all.firstIndex(of: route) ?? 0
    return all[(idx + 1) % all.count]
  }
}

// MARK: - Auth helper screens

private struct LoadingView: View {
  var body: some View {
    ZStack {
      Color.cardPageBackground.ignoresSafeArea()
      ProgressView().controlSize(.large)
    }
  }
}

private struct SignedOutView: View {
  @Environment(AuthState.self) private var auth
  @State private var email = ""
  @State private var sentTo: String?
  @State private var sending = false

  var body: some View {
    ZStack {
      Color.cardPageBackground.ignoresSafeArea()
      VStack(spacing: 20) {
        AtollCardLogo(size: 96)
        Text("AtollCard")
          .font(.system(size: 34, weight: .bold))
        Text("Digitale Visitenkarten für Atoll OS")
          .font(.system(.callout))
          .foregroundStyle(Color.cardTextSecondary)

        VStack(spacing: 8) {
          TextField("deine@email.ch", text: $email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.06)))

          Button(action: sendMagicLink) {
            HStack {
              if sending { ProgressView().tint(.white) }
              Text(sentTo == nil ? "Magic Link senden" : "Erneut senden")
                .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.primary, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
          }
          .disabled(email.isEmpty || sending)

          if let sentTo {
            Text("Magic Link gesendet an \(sentTo)")
              .font(.system(.footnote))
              .foregroundStyle(Color.cardPillGreenText)
          }
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
      }
    }
  }

  private func sendMagicLink() {
    sending = true
    Task {
      defer { sending = false }
      do {
        try await auth.sendMagicLink(to: email)
        sentTo = email
      } catch {
        // TODO: surface via ToastCenter
      }
    }
  }
}

#Preview {
  RootView()
    .environment(AuthState())
    .environment(CardStore(repository: MockCardRepository()))
    .environment(LeadStore(repository: MockLeadRepository()))
    .environment(AnalyticsStore(repository: MockAnalyticsRepository()))
    .environment(ToastCenter())
    .environment(ReachabilityMonitor())
}
