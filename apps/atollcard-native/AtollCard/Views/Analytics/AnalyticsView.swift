import SwiftUI
import Charts

/// Analytics dashboard — KPI cards on top, Swift Charts area below.
/// Scope toggles between aggregate and per-card; range toggles 7d/30d/90d/All.
struct AnalyticsView: View {
  @Environment(AnalyticsStore.self) private var analyticsStore
  @Environment(CardStore.self)      private var cardStore

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 0) {
        HeaderBar(pill: "Stats",
                  meta: analyticsStore.range.label)
        BigTitleView(leading: "Deine", accent: "Reichweite")

        scopePicker.padding(.horizontal, 24).padding(.top, 12)
        rangePicker.padding(.horizontal, 24).padding(.top, 8)

        if let stats = analyticsStore.current {
          kpis(stats).padding(.horizontal, 16).padding(.top, 16)
          chart(stats).padding(.horizontal, 16).padding(.top, 12)
          countries(stats).padding(.horizontal, 16).padding(.top, 12)
          fields(stats).padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 24)
        } else if analyticsStore.lastError != nil {
          Text("Konnte Analytics nicht laden.")
            .foregroundStyle(Color.cardPillRoseText)
            .padding(.horizontal, 24)
            .padding(.top, 24)
        } else {
          ProgressView().padding(.top, 60).frame(maxWidth: .infinity)
        }
      }
      .padding(.bottom, 24)
    }
    .background(Color.cardPageBackground)
    .task(id: scopeKey) { await analyticsStore.refresh() }
    .refreshable { await analyticsStore.refresh() }
  }

  // MARK: - Scope (Aggregate / per card)

  private var scopePicker: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 6) {
        scopePill("Gesamt", active: analyticsStore.scope == .aggregate) {
          analyticsStore.scope = .aggregate
        }
        ForEach(cardStore.cards) { card in
          scopePill(card.title.shortStatLabel, active: analyticsStore.scope == .card(card.id)) {
            analyticsStore.scope = .card(card.id)
          }
        }
      }
    }
  }

  private func scopePill(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(label)
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(active ? Color.primary : Color.cardSoftBackground, in: Capsule())
        .foregroundStyle(active ? Color.white : .primary)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Range (7d / 30d / 90d / All)

  private var rangePicker: some View {
    HStack(spacing: 6) {
      ForEach(DateRangeOption.allCases) { range in
        Button {
          analyticsStore.range = range
        } label: {
          Text(range.label)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(analyticsStore.range == range ? Color.cardPillBlueText : Color.cardPillBlue, in: Capsule())
            .foregroundStyle(analyticsStore.range == range ? Color.white : Color.cardPillBlueText)
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: - KPI cards

  @ViewBuilder
  private func kpis(_ stats: CardAnalytics) -> some View {
    let convPct = Int((stats.conversionRate * 100).rounded())
    HStack(spacing: 10) {
      kpi(title: "Scans", value: "\(stats.totalScans)", icon: "qrcode")
      kpi(title: "Leads", value: "\(stats.totalLeads)", icon: "person.crop.circle.badge.plus")
      kpi(title: "Conv.", value: "\(convPct)%", icon: "arrow.triangle.2.circlepath")
    }
  }

  private func kpi(title: String, value: String, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color.cardPillBlueText)
      Text(value)
        .font(.system(size: 24, weight: .bold))
        .tracking(-0.5)
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.cardTextMuted)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.black.opacity(0.04)))
  }

  // MARK: - Charts

  @ViewBuilder
  private func chart(_ stats: CardAnalytics) -> some View {
    Text("SCANS & LEADS")
      .font(.system(size: 11, weight: .heavy))
      .kerning(0.8)
      .foregroundStyle(Color.cardTextMuted)
      .padding(.leading, 4)

    Chart {
      ForEach(stats.scansByDay) { entry in
        BarMark(
          x: .value("Tag", entry.date, unit: .day),
          y: .value("Scans", entry.count)
        )
        .foregroundStyle(Color.cardPillBlueText)
      }
      ForEach(stats.leadsByDay) { entry in
        LineMark(
          x: .value("Tag", entry.date, unit: .day),
          y: .value("Leads", entry.count)
        )
        .foregroundStyle(Color.cardAccentRed)
        .interpolationMethod(.monotone)
        .symbol(.circle)
      }
    }
    .frame(height: 200)
    .padding(14)
    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.black.opacity(0.04)))
  }

  // MARK: - Countries

  @ViewBuilder
  private func countries(_ stats: CardAnalytics) -> some View {
    let sorted = stats.scansByCountry.sorted { $0.value > $1.value }
    if !sorted.isEmpty {
      Text("HERKUNFT")
        .font(.system(size: 11, weight: .heavy))
        .kerning(0.8)
        .foregroundStyle(Color.cardTextMuted)
        .padding(.leading, 4)

      VStack(spacing: 8) {
        ForEach(Array(sorted.prefix(6)), id: \.key) { (country, count) in
          HStack {
            Text(flag(for: country))
            Text(country).font(.system(.callout, weight: .semibold))
            Spacer()
            Text("\(count)").font(.system(.callout, weight: .medium)).foregroundStyle(Color.cardTextSecondary)
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 10)
          .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        }
      }
    }
  }

  // MARK: - Field tap distribution

  @ViewBuilder
  private func fields(_ stats: CardAnalytics) -> some View {
    let sorted = stats.scansByField.sorted { $0.value > $1.value }
    if !sorted.isEmpty {
      Text("WAS WIRD GETAPPED?")
        .font(.system(size: 11, weight: .heavy))
        .kerning(0.8)
        .foregroundStyle(Color.cardTextMuted)
        .padding(.leading, 4)
      Chart {
        ForEach(sorted, id: \.key) { (field, count) in
          BarMark(
            x: .value("Anzahl", count),
            y: .value("Feld", field.rawValue)
          )
          .foregroundStyle(Color.cardPillBlueText.opacity(0.85))
        }
      }
      .frame(height: CGFloat(40 * sorted.count))
      .padding(14)
      .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }
  }

  // MARK: - Helpers

  private var scopeKey: String {
    switch analyticsStore.scope {
    case .aggregate: "aggregate-\(analyticsStore.range.rawValue)"
    case .card(let id): "card-\(id)-\(analyticsStore.range.rawValue)"
    }
  }

  /// ISO-3166-1 alpha-2 → flag emoji.
  private func flag(for iso: String) -> String {
    let base: UInt32 = 127397
    var s = ""
    for scalar in iso.uppercased().unicodeScalars {
      if let v = UnicodeScalar(base + scalar.value) { s.append(Character(v)) }
    }
    return s
  }
}

private extension String {
  /// "PADI Course Director" → "CD"
  var shortStatLabel: String {
    if contains("Course Director") { "CD" }
    else if contains("SeaExplorers") { "SE" }
    else if contains("Privat") { "Privat" }
    else { self }
  }
}
