import SwiftUI

struct AssignmentsView: View {
  let user: CurrentUser

  var body: some View {
    NavigationStack {
      ContentUnavailableView(
        "Meine Einsätze",
        systemImage: "calendar",
        description: Text("Phase 1b: Einsätze-Liste lädt hier")
      )
      .navigationTitle("Einsätze")
    }
  }
}
