import SwiftUI

struct TodayView: View {
  let user: CurrentUser

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          BrandHeader()

          VStack(alignment: .leading, spacing: 6) {
            Text("Hi, \(user.firstName) 👋")
              .font(.largeTitle.bold())
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
              .foregroundStyle(.secondary)
          }
          .padding(.horizontal)

          ContentUnavailableView(
            "Heute keine Einsätze",
            systemImage: "sun.max",
            description: Text("Phase 1b: Heute-Daten laden")
          )
          .padding(.top, 40)
        }
      }
      .toolbar(.hidden, for: .navigationBar)
    }
  }
}
