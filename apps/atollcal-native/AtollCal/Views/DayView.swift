import SwiftUI

struct DayView: View {
  @Binding var date: Date
  var body: some View {
    VStack {
      Text("DayView — Implementation in Task 8–9")
      Text(date, style: .date).font(.caption).foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
