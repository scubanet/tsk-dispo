import SwiftUI
import AtollHub

/// WhatsApp-Markenfarbe (#25D366) — fuer Icon/Label aller WhatsApp-Nachrichten.
let komboxWhatsAppGreen = Color(red: 0.145, green: 0.827, blue: 0.4)

/// WhatsApp-Marker: gruenes Logo-Symbol + „WhatsApp" gruen (in/out gleich).
private struct WhatsAppTag: View {
  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "message.fill").font(.system(size: 9))
      Text("WhatsApp").font(.system(size: 10, weight: .semibold))
    }
    .foregroundStyle(komboxWhatsAppGreen)
  }
}

/// WhatsApp-Bubble: inbound links/hell, outbound rechts/gruen — WhatsApp-Marker
/// (gruenes Icon + Label) auf beiden, wie in der Webversion.
struct KomboxBubble: View {
  let event: KomboxEvent
  private var isOutbound: Bool { event.direction == .outbound }

  private static let time: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    HStack {
      if isOutbound { Spacer(minLength: 40) }
      VStack(alignment: .leading, spacing: 3) {
        WhatsAppTag()
        Text(event.body ?? event.summary).font(.callout)
        Text(Self.time.string(from: event.timestamp))
          .font(.caption2).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .padding(9)
      .frame(maxWidth: 360, alignment: .leading)
      .background(isOutbound ? komboxWhatsAppGreen.opacity(0.18) : Color.secondary.opacity(0.12),
                  in: RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12)
        .strokeBorder(komboxWhatsAppGreen.opacity(isOutbound ? 0.35 : 0.18), lineWidth: 1))
      if !isOutbound { Spacer(minLength: 40) }
    }
  }
}

/// Mail-Karte: aufklappbar (Betreff -> Body).
struct KomboxMailCard: View {
  let event: KomboxEvent
  @State private var expanded = false
  private var isOutbound: Bool { event.direction == .outbound }

  private static let time: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd.MM. HH:mm"
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    HStack {
      if isOutbound { Spacer(minLength: 40) }
      VStack(alignment: .leading, spacing: 6) {
        Button { expanded.toggle() } label: {
          HStack(spacing: 8) {
            Image(systemName: "envelope.fill").foregroundStyle(CoColor.accent)
            VStack(alignment: .leading, spacing: 1) {
              Text(isOutbound ? "Gesendet · E-Mail" : "Empfangen · E-Mail")
                .font(.system(size: 10, weight: .semibold)).foregroundStyle(CoColor.accent)
              Text(event.subject ?? event.summary).font(.callout.weight(.medium)).lineLimit(1)
              if !expanded, let body = event.body, !body.isEmpty {
                Text(body).font(.caption).foregroundStyle(.secondary).lineLimit(1)
              }
            }
            Spacer(minLength: 0)
            Text(Self.time.string(from: event.timestamp)).font(.caption2).foregroundStyle(.secondary)
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
              .font(.caption).foregroundStyle(.tertiary)
          }
        }
        .buttonStyle(.plain)
        if expanded, let body = event.body {
          Text(body).font(.callout).textSelection(.enabled)
        }
      }
      .padding(10)
      .frame(maxWidth: 460, alignment: .leading)
      .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
      if !isOutbound { Spacer(minLength: 40) }
    }
  }
}

/// System-Marker: zentrierter Hinweis (Notiz/Anruf/Task/...).
struct KomboxSystemMarker: View {
  let event: KomboxEvent
  var body: some View {
    HStack {
      Spacer()
      HStack(spacing: 6) {
        Image(systemName: "info.circle").font(.caption2)
        Text(event.summary).font(.caption).lineLimit(1)
      }
      .padding(.horizontal, 10).padding(.vertical, 4)
      .background(.quaternary.opacity(0.5), in: Capsule())
      Spacer()
    }
  }
}

/// Waehlt die richtige Zeile je `KomboxKind`.
struct KomboxRow: View {
  let event: KomboxEvent
  var body: some View {
    switch event.kind {
    case .whatsapp: KomboxBubble(event: event)
    case .email:    KomboxMailCard(event: event)
    case .system:   KomboxSystemMarker(event: event)
    }
  }
}
