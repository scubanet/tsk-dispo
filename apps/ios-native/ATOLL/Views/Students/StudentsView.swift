import SwiftUI

/// Placeholder für Etappe 6 — Global Studenten-Tab mit Suche & Filter.
/// In Etappe 2 wird nur der Tab eingeführt, damit die App-Navigation
/// die finale 4-Tab-Form hat.
struct StudentsView: View {
  let user: CurrentUser

  var body: some View {
    NavigationStack {
      ContentUnavailableView {
        Label("Studenten", systemImage: "person.2.fill")
      } description: {
        Text("Übersicht über alle deine Schüler — kommt in einer der nächsten Updates.")
      }
      .navigationTitle("Studenten")
    }
  }
}
