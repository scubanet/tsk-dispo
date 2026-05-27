import SwiftUI
import AtollDesign

/// The persona business card — 280×170 in the horizontal gallery,
/// scales fluidly to fill its container if `fillWidth: true`.
///
/// Renders the persona gradient with a soft radial highlight, the brand
/// header ("ATOLL"), the badge ("PADI CD"), name, role, and a stat strip
/// at the bottom (SCANS · LEADS · DEFAULT?).
struct BizCardView: View {
  let card: Card
  let person: Person
  var scansCount: Int = 0
  var leadsCount: Int = 0
  var fillWidth: Bool = false

  var body: some View {
    ZStack(alignment: .topTrailing) {
      LinearGradient.persona(card.theme)

      // Radial highlight in the corner — same as the mockup's ::before pseudo.
      RadialGradient(
        colors: [Color.white.opacity(0.15), Color.white.opacity(0)],
        center: .topTrailing,
        startRadius: 8,
        endRadius: 180
      )
      .allowsHitTesting(false)

      VStack(alignment: .leading, spacing: 0) {
        // Top row: AtollCard logo + persona badge
        HStack(alignment: .top) {
          HStack(spacing: 6) {
            // White-tinted logo so it sits readable on the gradient.
            AtollCardLogo(size: 22)
              .colorMultiply(.white)
            Text("ATOLL")
              .font(.system(size: 10, weight: .heavy))
              .kerning(1.5)
              .opacity(0.9)
          }
          Spacer()
          if let badge = card.badge {
            Text(badge)
              .font(.system(size: 9, weight: .heavy))
              .kerning(0.8)
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(.white.opacity(0.2), in: Capsule())
              .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 0.5))
          }
        }

        Spacer()

        // Bottom: name + role + stats
        VStack(alignment: .leading, spacing: 2) {
          Text(person.fullName)
            .font(.system(size: 22, weight: .bold))
            .tracking(-0.4)
            .lineLimit(1)
          Text(card.subtitleLine)
            .font(.system(size: 12))
            .opacity(0.85)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.bottom, 8)
          HStack(spacing: 12) {
            statText("\(scansCount) SCANS")
            dot
            statText("\(leadsCount) LEADS")
            if card.isDefault {
              dot
              statText("DEFAULT")
            }
          }
          .font(.system(size: 10, weight: .semibold))
          .opacity(0.85)
        }
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 18)
    }
    .foregroundStyle(.white)
    .frame(maxWidth: fillWidth ? .infinity : 280)
    .frame(height: fillWidth ? 200 : 170)
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 12)
    .shadow(color: .black.opacity(0.08), radius: 6,  x: 0, y: 4)
  }

  private func statText(_ s: String) -> some View {
    Text(s).tracking(0.3)
  }

  private var dot: some View {
    Text("·").opacity(0.5)
  }
}

private extension Card {
  /// e.g. "PADI Course Director · #226710"
  var subtitleLine: String {
    if let subtitle, !subtitle.isEmpty { return "\(title) · \(subtitle)" }
    return title
  }
}

#Preview {
  ScrollView(.horizontal) {
    HStack(spacing: 16) {
      BizCardView(card: MockSeed.cards[0], person: MockSeed.dominik,
                  scansCount: 34, leadsCount: 11)
      BizCardView(card: MockSeed.cards[1], person: MockSeed.dominik,
                  scansCount: 9,  leadsCount: 3)
      BizCardView(card: MockSeed.cards[2], person: MockSeed.dominik,
                  scansCount: 2,  leadsCount: 0)
    }
    .padding()
  }
  .background(Color.cardPageBackground)
}
