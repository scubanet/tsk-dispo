import SwiftUI
import AtollDesign
import PassKit

/// White card block under the gallery — header (avatar + title + live URL),
/// context pills, 3 stats, 4 quick actions, mini QR with "Vollbild öffnen".
struct PersonaDetailCard: View {
  let card: Card
  let person: Person

  @Environment(LeadStore.self)   private var leadStore
  @Environment(ToastCenter.self) private var toast

  @State private var showShareSheet  = false
  @State private var showFullscreen  = false
  @State private var showNFC         = false
  @State private var showEditor      = false

  // Wallet-pass flow: `addingPassFor` triggers the async fetch via .task(id:);
  // result is parked in `presentingPassVC` (Identifiable wrapper) for sheet.
  @State private var addingPassFor:    Card?
  @State private var presentingPassVC: WalletPassPresentation?

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      contextPills
      StatTriple(items: stats)
      quickActions
      MiniQRRow(card: card, onTap: { showFullscreen = true })
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 18)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
    .overlay(
      RoundedRectangle(cornerRadius: 24).stroke(.black.opacity(0.03))
    )
    .shadow(color: .black.opacity(0.04), radius: 12, y: 2)
    .sheet(isPresented: $showShareSheet) {
      CardShareSheet(card: card, person: person)
        .presentationDetents([.medium, .large])
    }
    .sheet(isPresented: $showFullscreen) {
      FullscreenQRView(card: card, person: person)
    }
    .sheet(isPresented: $showNFC) {
      NFCWriteSheet(card: card)
        .presentationDetents([.medium])
    }
    .sheet(item: $presentingPassVC) { wrap in
      PKAddPassesViewControllerRepresentable(viewController: wrap.viewController)
    }
    .task(id: addingPassFor?.id) {
      guard let card = addingPassFor else { return }
      addingPassFor = nil
      do {
        let vc = try await WalletPassService().passViewController(for: card)
        presentingPassVC = WalletPassPresentation(viewController: vc)
      } catch {
        toast.show("Wallet: \(error.localizedDescription)", kind: .error)
      }
    }
    .sheet(isPresented: $showEditor) {
      CardEditorSheet(card: card)
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack(spacing: 12) {
      Avatar(initials: person.initials, colorHex: person.avatarColorHex)
        .frame(width: 44, height: 44)
      VStack(alignment: .leading, spacing: 2) {
        Text(card.title)
          .font(.system(size: 17, weight: .bold))
          .tracking(-0.3)
        HStack(spacing: 4) {
          Circle().fill(Color.cardPillGreenText).frame(width: 8, height: 8)
          Text("Live · \(card.publicURL.host ?? "")\(card.publicURL.path)")
            .font(.system(size: 12))
            .foregroundStyle(Color.cardTextMuted)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
      Spacer(minLength: 0)
      Button {
        showEditor = true
      } label: {
        Image(systemName: "pencil")
          .font(.system(size: 14, weight: .semibold))
          .frame(width: 32, height: 32)
          .background(Color.cardSoftBackground, in: Circle())
          .foregroundStyle(.primary)
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Context pills

  private var contextPills: some View {
    let dive = card.diveProfile
    var pills: [PillRow.PillItem] = []

    // Lead-style pill — "CD · TL/DM" with dark blue badge
    if let badge = card.badge, badge.count <= 12 {
      pills.append(.init(label: card.title.shortLabel, tone: .blue, badge: badge))
    }

    // Specialty pills — show first 4 + "+N"
    if let specialties = dive?.specialties, !specialties.isEmpty {
      for spec in specialties.prefix(4) {
        pills.append(.init(label: spec, tone: PillTone.tone(for: spec)))
      }
      if specialties.count > 4 {
        pills.append(.init(label: "+\(specialties.count - 4)", tone: .purple))
      }
    }
    return PillRow(items: pills)
  }

  // MARK: - Stats

  private var stats: [StatTriple.Item] {
    let analytics = MockSeed.analytics(for: card.id, range: .thirtyDays)
    let conv = Int((analytics.conversionRate * 100).rounded())
    return [
      .init(number: "\(analytics.totalScans)", label: "Scans"),
      .init(number: "\(leadStore.leads.filter { $0.cardId == card.id }.count)", label: "Leads"),
      .init(number: "\(conv)%", label: "Conv.")
    ]
  }

  // MARK: - Actions

  private var quickActions: some View {
    QuickActionGrid(items: [
      .init(icon: "qrcode",                 label: "QR",     primary: true,
            action: { showFullscreen = true }),
      .init(icon: "square.and.arrow.up",    label: "Share",
            action: { showShareSheet = true }),
      .init(icon: "wave.3.right",           label: "NFC",
            action: {
              if NFCWriterController.isAvailable {
                showNFC = true
              } else {
                toast.show("NFC nicht verfügbar (Simulator?)", kind: .error)
              }
            }),
      .init(icon: "creditcard",             label: "Wallet",
            action: { addingPassFor = card })
    ])
  }
}

/// Identifiable wrapper around `PKAddPassesViewController` so it can be
/// used with SwiftUI's `sheet(item:)`.
private struct WalletPassPresentation: Identifiable {
  let id = UUID()
  let viewController: PKAddPassesViewController
}

/// Bridges `PKAddPassesViewController` (UIKit) into SwiftUI.
private struct PKAddPassesViewControllerRepresentable: UIViewControllerRepresentable {
  let viewController: PKAddPassesViewController
  func makeUIViewController(context: Context) -> PKAddPassesViewController { viewController }
  func updateUIViewController(_ uiViewController: PKAddPassesViewController, context: Context) {}
}

private extension String {
  /// Trims "PADI Course Director" → "PADI · TL/DM"; keeps short titles intact.
  var shortLabel: String {
    if contains("Course Director") { return "CD · TL/DM" }
    if contains("SeaExplorers")    { return "SeaExplorers" }
    return self
  }
}

// MARK: - Mini QR row

private struct MiniQRRow: View {
  let card: Card
  var onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 14) {
        QRCodeView(url: card.publicURL, logoFraction: 0.18)
          .frame(width: 80, height: 80)
          .background(Color(hex: 0x1A1F2E), in: RoundedRectangle(cornerRadius: 8))
          .padding(6)
          .background(
            LinearGradient(colors: [Color(hex: 0xFAF7F0), Color(hex: 0xF0EBE0)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14)
          )
        VStack(alignment: .leading, spacing: 4) {
          Text("TAP ZUM VOLLBILD TEILEN")
            .font(.system(size: 10, weight: .heavy))
            .kerning(0.8)
            .foregroundStyle(Color.cardTextMuted)
          Text("\(card.publicURL.host ?? "")\(card.publicURL.path)")
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(Color.cardTextSecondary)
            .lineLimit(1)
          Text("Vollbild öffnen →")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(hex: 0x2563EB))
            .padding(.top, 2)
        }
        Spacer(minLength: 0)
      }
      .padding(10)
      .background(
        LinearGradient(colors: [Color(hex: 0xFAF7F0), Color(hex: 0xF0EBE0)],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        in: RoundedRectangle(cornerRadius: 16)
      )
    }
    .buttonStyle(.plain)
  }
}
