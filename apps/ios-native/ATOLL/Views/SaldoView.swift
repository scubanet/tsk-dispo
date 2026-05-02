import SwiftUI

struct SaldoView: View {
  let user: CurrentUser

  var body: some View {
    NavigationStack {
      ContentUnavailableView(
        "Mein Saldo",
        systemImage: "creditcard",
        description: Text("Phase 1c: Saldo + Bewegungen lädt hier")
      )
      .navigationTitle("Saldo")
    }
  }
}
