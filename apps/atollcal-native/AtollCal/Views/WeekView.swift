import SwiftUI

struct WeekView: View {
  @Binding var anchor: Date
  var body: some View {
    VStack {
      Text("WeekView — Implementation in Task 11")
      Text(anchor, style: .date).font(.caption).foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
