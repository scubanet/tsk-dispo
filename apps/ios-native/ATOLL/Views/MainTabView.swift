import SwiftUI

struct MainTabView: View {
  let user: CurrentUser

  var body: some View {
    TabView {
      Tab("Heute", systemImage: "sun.max.fill") {
        TodayView(user: user)
      }
      Tab("Einsätze", systemImage: "calendar") {
        AssignmentsView(user: user)
      }
      Tab("Saldo", systemImage: "creditcard.fill") {
        SaldoView(user: user)
      }
      Tab("Profil", systemImage: "person.crop.circle.fill") {
        ProfileView(user: user)
      }
    }
    .tint(.accentColor)
  }
}
