import SwiftUI
import AtollDesign

/// Inbox row — colored avatar circle, name (+ NEU badge), context, time + ABook hint.
struct LeadRowView: View {
  let lead: Lead
  var cardBadge: String? = nil           // "CD" / "SE"

  var body: some View {
    HStack(spacing: 12) {
      Avatar(initials: lead.initials, colorHex: lead.avatarColorHex)
        .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(lead.fullName.isEmpty ? lead.firstName : lead.fullName)
            .font(.system(size: 14, weight: .semibold))
          if lead.status == .new {
            NewBadge()
          }
        }
        HStack(spacing: 6) {
          if let cardBadge {
            Text(cardBadge)
              .font(.system(size: 9, weight: .heavy))
              .kerning(0.5)
              .foregroundStyle(.white)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.cardPillBlueText, in: Capsule())
          }
          Text(lead.topic ?? "—")
            .font(.system(size: 12))
            .foregroundStyle(Color.cardTextMuted)
        }
      }

      Spacer(minLength: 0)

      VStack(alignment: .trailing, spacing: 2) {
        Text(Self.relative(lead.capturedAt))
          .font(.system(size: 11))
          .foregroundStyle(Color.cardTextMuted)
        if !lead.importedToAddressBook {
          Text("→ ABook")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(hex: 0x2563EB))
        } else {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 13))
            .foregroundStyle(Color.cardPillGreenText)
        }
      }
    }
    .padding(.vertical, 14)
    .padding(.horizontal, 16)
    .glassCard(cornerRadius: 18)
  }

  private static func relative(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = Locale(identifier: "de_CH")
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: .now)
  }
}

/// "NEU" pill — small blue capsule.
private struct NewBadge: View {
  var body: some View {
    Text("NEU")
      .font(.system(size: 9, weight: .heavy))
      .kerning(0.5)
      .foregroundStyle(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Color(hex: 0x2563EB), in: Capsule())
  }
}

#Preview {
  VStack(spacing: 8) {
    LeadRowView(lead: MockSeed.leads[0], cardBadge: "CD")
    LeadRowView(lead: MockSeed.leads[1], cardBadge: "SE")
    LeadRowView(lead: MockSeed.leads[6], cardBadge: "CD")
  }
  .padding()
  .background(Color.cardPageBackground)
}
