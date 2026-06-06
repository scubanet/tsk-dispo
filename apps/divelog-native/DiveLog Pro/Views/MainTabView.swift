import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var store = StoreManager.shared
    @State private var showPaywall = false

    var body: some View {
        TabView(selection: $selectedTab) {
            LogbookTab()
                .tabItem {
                    Label(L10n.tabLogbook, systemImage: "book.closed")
                }
                .tag(0)

            JournalTab()
                .tabItem {
                    Label(L10n.tabJournal, systemImage: "photo.stack")
                }
                .tag(1)

            Group {
                if store.isPro {
                    SignTab()
                } else {
                    ProTeaser { showPaywall = true }
                }
            }
            .tabItem {
                Label(L10n.tabSign, systemImage: "signature")
            }
            .tag(2)

            StatsTab()
                .tabItem {
                    Label(L10n.tabStats, systemImage: "chart.bar.xaxis")
                }
                .tag(3)

            ProfileTab()
                .tabItem {
                    Label(L10n.tabProfile, systemImage: "person.crop.circle")
                }
                .tag(4)
        }
        .tint(.appAccent)
        .observeLanguage()
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

/// Shown in the Sign tab when Instructor Pro is not purchased.
private struct ProTeaser: View {
    let onUpgrade: () -> Void

    @AppStorage("appLanguage") private var appLanguage: String = "en"
    private var isDE: Bool { appLanguage == "de" }

    var body: some View {
        NavigationStack {
            ZStack {
                HeroBackground()

                VStack(spacing: DSSpacing.xl) {
                    Spacer()

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Color.appAccent.opacity(0.7))

                    VStack(spacing: DSSpacing.s) {
                        Text("Instructor Pro")
                            .font(.title2.weight(.bold))

                        Text(isDE
                             ? "Verwalte Schüler, bewerte Skills und dokumentiere Kurse."
                             : "Manage students, assess skills, and document courses.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DSSpacing.xxl)
                    }

                    Button(action: onUpgrade) {
                        Text(isDE ? "Mehr erfahren" : "Learn more")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: 220, minHeight: 48)
                            .background(Color.appAccent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: DSRadius.l))
                    }

                    Spacer()
                }
            }
            .navigationTitle(L10n.tabSign)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
