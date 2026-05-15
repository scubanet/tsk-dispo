import SwiftUI

struct MonthView: View {
  @Binding var anchor: Date
  var body: some View {
    VStack {
      Text("MonthView — Implementation in Task 12–14")
      Text(anchor, style: .date).font(.caption).foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
