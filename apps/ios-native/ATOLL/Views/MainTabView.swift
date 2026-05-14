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
                    Label("Kurse", systemImage: "calendar")
                }
            StudentsView(user: user)
                .tabItem {
                    Label("Studenten", systemImage: "person.2.fill")
                }
            ProfileView(user: user)
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle.fill")
                }
        }
        .tint(.accentColor)
    }
}
