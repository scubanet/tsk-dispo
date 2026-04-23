import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

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

            SignTab()
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
        // System tint — on iOS 26 the tab bar adopts Liquid Glass automatically
        .tint(.appAccent)
        .observeLanguage()
    }
}
