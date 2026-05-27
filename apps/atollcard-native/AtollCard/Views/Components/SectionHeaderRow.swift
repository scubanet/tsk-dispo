import SwiftUI

/// Small uppercase section header — same shape as AtollCal's
/// "HEUTE · 22.05.26" rows. Used on the home screen and Leads inbox.
struct SectionHeaderRow: View {
  let label: String
  var subtitle: String? = nil
  var trailing: String? = nil

  var body: some View {
    HStack {
      HStack(spacing: 6) {
        Text(label)
          .font(.system(size: 12, weight: .heavy))
          .kerning(1.2)
        if let subtitle {
          Text("· \(subtitle)")
            .font(.system(size: 12, weight: .medium))
            .kerning(0.5)
            .foregroundStyle(Color.cardTextMuted)
        }
      }
      .foregroundStyle(Color.primary)
      Spacer()
      if let trailing {
        Text(trailing)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(Color.cardTextSecondary)
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 20)
    .padding(.bottom, 8)
  }
}

#Preview {
  VStack(spacing: 0) {
    SectionHeaderRow(label: "HEUTE", subtitle: "22.05.26", trailing: "2 neu")
    SectionHeaderRow(label: "GESTERN", subtitle: "21.05.26")
    SectionHeaderRow(label: "DIESE WOCHE", subtitle: "18.–24.05.", trailing: "10")
  }
  .background(Color.cardPageBackground)
}
