import SwiftUI

struct MainTabView: View {
    let user: CurrentUser

    var body: some View {
        TabView {
            TodayView(user: user)
                .tabItem {
                    Label("Heute", systemImage: "sun.max.fill")
                }
            CalendarView(user: user)
                .tabItem {
                    Label("Kalender", systemImage: "calendar")
                }
            AssignmentsView(user: user)
                .tabItem {
                    Label("Einsätze", systemImage: "list.bullet.rectangle")
                }
            SaldoView(user: user)
                .tabItem {
                    Label("Saldo", systemImage: "creditcard.fill")
                }
            ProfileView(user: user)
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(.accentColor)
    }
}
