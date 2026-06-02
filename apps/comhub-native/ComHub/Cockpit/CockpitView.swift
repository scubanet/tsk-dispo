import SwiftUI
import AtollCore
import AtollHub

/// Heute-Cockpit im CoHub-Look: Begruessung + „Heutiger Tagesablauf"-Karte +
/// Vorschau-Widgets (Aufgaben/Kombox/CardInbox). Sektionen verlinken ins Modul.
struct CockpitView: View {
  @Environment(Hub.self) private var hub
  @Environment(AuthState.self) private var auth
  @State private var store = CockpitStore()

  let onOpenModule: (ComHubModule) -> Void

  private static let dateHeader: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EEEE, d. MMMM yyyy"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()
  private static let time: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  private var firstName: String {
    if case .signedIn(let u) = auth.status, !u.firstName.isEmpty { return u.firstName }
    return ""
  }
  private var greeting: String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    return Greeting.phrase(forHour: cal.component(.hour, from: Date()))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 22) {
        greetingBlock
        layout
      }
      .padding(.horizontal, 34).padding(.vertical, 30)
      .frame(maxWidth: 1080, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .task(id: reloadKey) { await store.reload(using: hub) }
  }

  private var reloadKey: String {
    if case .signedIn(let u) = auth.status { return "in:\(u.id.uuidString)" }
    return "out"
  }

  private var greetingBlock: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(Self.dateHeader.string(from: Date()).uppercased())
        .font(.system(size: 13, weight: .semibold)).foregroundStyle(CoColor.accent)
      Text(firstName.isEmpty ? "\(greeting)." : "\(greeting), \(firstName).")
        .font(.system(size: 30, weight: .heavy))
      summaryLine
    }
  }

  private var summaryLine: some View {
    let nEv = store.todayEvents.count
    let nTasks = store.openTasks.count
    let nMsg = store.recentConversations.count
    return (
      Text("Du hast ")
      + Text("\(nEv) Termine").bold()
      + Text(", ")
      + Text("\(nTasks) Aufgaben").bold()
      + Text(" und ")
      + Text("\(nMsg) neue").bold()
      + Text(" Nachrichten heute.")
    )
    .font(.system(size: 15)).foregroundStyle(.secondary)
  }

  private var layout: some View {
    HStack(alignment: .top, spacing: 18) {
      agendaCard.frame(maxWidth: .infinity)
      VStack(spacing: 18) {
        tasksWidget
        komboxWidget
        cardInboxWidget
      }
      .frame(width: 320)
    }
  }

  // MARK: - Agenda

  private var agendaCard: some View {
    CoCard {
      VStack(alignment: .leading, spacing: 0) {
        Button { onOpenModule(.kalender) } label: {
          HStack(spacing: 9) {
            Image(systemName: "calendar").foregroundStyle(CoColor.module(.kalender))
            Text("Heutiger Tagesablauf").font(.system(size: 15, weight: .bold))
            Spacer()
          }
          .padding(.horizontal, 18).padding(.top, 15).padding(.bottom, 12)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if store.todayEvents.isEmpty {
          Text("Keine Termine heute").font(.callout).foregroundStyle(.secondary)
            .padding(.horizontal, 18).padding(.bottom, 18)
        } else {
          VStack(spacing: 0) {
            ForEach(Array(store.todayEvents.enumerated()), id: \.element.id) { i, ev in
              agendaRow(ev, showDivider: i > 0)
            }
          }
          .padding(.horizontal, 18).padding(.bottom, 18)
        }
      }
    }
  }

  private func agendaRow(_ ev: UnifiedEvent, showDivider: Bool) -> some View {
    HStack(spacing: 14) {
      VStack(alignment: .trailing, spacing: 0) {
        Text(ev.isAllDay ? "—" : Self.time.string(from: ev.start))
          .font(.system(size: 13.5, weight: .bold)).foregroundStyle(.primary)
        if !ev.isAllDay {
          Text(Self.time.string(from: ev.end)).font(.system(size: 11)).foregroundStyle(.tertiary)
        }
      }
      .frame(width: 46, alignment: .trailing)
      RoundedRectangle(cornerRadius: 3)
        .fill(ev.source.type == .atoll ? CoColor.accent : Color.secondary)
        .frame(width: 4).frame(minHeight: 34)
      VStack(alignment: .leading, spacing: 1) {
        Text(ev.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
        if let loc = ev.location, !loc.isEmpty {
          Label(loc, systemImage: "mappin").font(.system(size: 12)).foregroundStyle(.tertiary)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 10)
    .overlay(alignment: .top) {
      if showDivider { Divider() }
    }
  }

  // MARK: - Widgets

  private func widgetCard<Content: View>(_ module: ComHubModule, title: String, icon: String,
                                         count: Int, @ViewBuilder content: @escaping () -> Content) -> some View {
    CoCard {
      VStack(alignment: .leading, spacing: 0) {
        Button { onOpenModule(module) } label: {
          HStack(spacing: 9) {
            Image(systemName: icon).foregroundStyle(CoColor.module(module))
            Text(title).font(.system(size: 14, weight: .bold))
            Spacer()
            Text("\(count)").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
          }
          .padding(.horizontal, 16).padding(.top, 13).padding(.bottom, 10)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        VStack(alignment: .leading, spacing: 0) { content() }
          .padding(.horizontal, 16).padding(.bottom, 14)
      }
    }
  }

  private var tasksWidget: some View {
    widgetCard(.tasks, title: "Aufgaben heute", icon: "checklist", count: store.openTasks.count) {
      if store.openTasks.isEmpty {
        Text("Keine Aufgaben fällig 🎉").font(.system(size: 12.5)).foregroundStyle(.tertiary).padding(.vertical, 4)
      } else {
        ForEach(store.openTasks.prefix(4)) { task in
          HStack(spacing: 9) {
            Circle().strokeBorder(.tertiary, lineWidth: 1.8).frame(width: 16, height: 16)
            Text(task.title).font(.system(size: 13)).lineLimit(1)
            Spacer(minLength: 0)
          }
          .padding(.vertical, 6)
        }
      }
    }
  }

  private var komboxWidget: some View {
    widgetCard(.kombox, title: "Kombox", icon: "bubble.left.and.bubble.right",
               count: store.recentConversations.count) {
      if store.recentConversations.isEmpty {
        Text("Keine neuen Nachrichten").font(.system(size: 12.5)).foregroundStyle(.tertiary).padding(.vertical, 4)
      } else {
        ForEach(store.recentConversations.prefix(3)) { conv in
          HStack(spacing: 10) {
            CoAvatar(name: conv.contactName, size: 30)
            VStack(alignment: .leading, spacing: 1) {
              Text(conv.contactName).font(.system(size: 13, weight: .semibold)).lineLimit(1)
              Text(conv.lastEvent.kind == .email ? (conv.lastEvent.subject ?? conv.lastEvent.summary)
                                                  : (conv.lastEvent.body ?? conv.lastEvent.summary))
                .font(.system(size: 12)).foregroundStyle(.tertiary).lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(conv.lastEvent.kind == .email ? "Mail" : (conv.lastEvent.kind == .whatsapp ? "WhatsApp" : "Log"))
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(conv.lastEvent.kind == .whatsapp ? CoColor.module(.kombox) : CoColor.accent)
          }
          .padding(.vertical, 7)
        }
      }
    }
  }

  private var cardInboxWidget: some View {
    widgetCard(.cardInbox, title: "CardInbox", icon: "tray.and.arrow.down", count: 0) {
      Text("Noch keine neuen Leads").font(.system(size: 12.5)).foregroundStyle(.tertiary).padding(.vertical, 4)
    }
  }
}
