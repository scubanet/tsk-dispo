import SwiftUI

/// Top header — "Heute"-pill on the left + meta label on the right.
struct HeaderBar: View {
  let pill: String
  let meta: String

  var body: some View {
    HStack {
      Text(pill)
        .font(.system(size: 19, weight: .medium))
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.white, in: Capsule())
        .overlay(Capsule().stroke(.black.opacity(0.04), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
      Spacer()
      Text(meta)
        .font(.system(size: 15, weight: .medium))
        .foregroundStyle(Color.cardTextSecondary)
    }
    .padding(.horizontal, 24)
    .padding(.top, 12)
  }
}

/// Big title with red accent word — "Meine [Karten]" / "Inbox [2026]".
struct BigTitleView: View {
  let leading: String
  let accent: String
  var trailing: AnyView? = nil

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(leading) + Text(" ") + Text(accent).foregroundStyle(Color.cardAccentRed)
      Spacer()
      if let trailing { trailing }
    }
    .font(.system(size: 38, weight: .bold))
    .tracking(-1)
    .padding(.horizontal, 24)
    .padding(.top, 16)
  }
}

/// Horizontal tab-pill bar (Personas / Leads / Team / Stats).
struct TabPillBar: View {
  let tabs: [Tab]
  @Binding var selection: String

  struct Tab: Identifiable, Hashable {
    let id: String          // key, e.g. "personas"
    let label: String
    var count: Int? = nil
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 4) {
        ForEach(tabs) { tab in
          tabPill(tab)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 16)
    }
  }

  private func tabPill(_ tab: Tab) -> some View {
    let active = selection == tab.id
    return Button {
      withAnimation(.easeOut(duration: 0.15)) { selection = tab.id }
    } label: {
      HStack(spacing: 4) {
        Text(tab.label)
        if let count = tab.count {
          Text("\(count)")
            .opacity(active ? 0.7 : 0.6)
            .font(.system(size: 13, weight: .medium))
        }
      }
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(active ? Color.white : .cardTextSecondary)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(active ? Color.primary : .clear, in: Capsule())
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  VStack(spacing: 0) {
    HeaderBar(pill: "Cards", meta: "3 Personas")
    BigTitleView(leading: "Meine", accent: "Karten")
    TabPillBar(tabs: [
      .init(id: "personas", label: "Personas", count: 3),
      .init(id: "leads",    label: "Leads",    count: 14),
      .init(id: "team",     label: "Team"),
      .init(id: "stats",    label: "Stats")
    ], selection: .constant("personas"))
  }
  .background(Color.cardPageBackground)
}
