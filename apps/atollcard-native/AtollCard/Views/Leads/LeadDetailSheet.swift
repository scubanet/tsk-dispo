import SwiftUI
import UIKit

/// Lead detail — shown as a sheet from the inbox row. Header (avatar + name),
/// captured fields, topic / message, then a primary "→ Address Book" CTA
/// and status controls.
struct LeadDetailSheet: View {
  let lead: Lead

  @Environment(LeadStore.self)   private var leadStore
  @Environment(ToastCenter.self) private var toast
  @Environment(\.dismiss)        private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          header
          fieldGrid
          if let msg = lead.message, !msg.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
              Text("NACHRICHT").font(.system(size: 11, weight: .heavy)).kerning(0.8).foregroundStyle(Color.cardTextMuted)
              Text(msg).font(.system(.body))
            }
          }
          actions
        }
        .padding(20)
      }
      .background(Color.cardPageBackground)
      .navigationTitle("Lead")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(String(localized: "Fertig")) { dismiss() }
        }
      }
    }
  }

  // MARK: - Header

  private var header: some View {
    HStack(spacing: 14) {
      Avatar(initials: lead.initials, colorHex: lead.avatarColorHex)
        .frame(width: 56, height: 56)
      VStack(alignment: .leading, spacing: 2) {
        Text(lead.fullName.isEmpty ? lead.firstName : lead.fullName)
          .font(.system(size: 20, weight: .bold))
          .tracking(-0.3)
        if let topic = lead.topic {
          Text(topic)
            .font(.system(size: 13))
            .foregroundStyle(Color.cardTextSecondary)
        }
        Text(lead.capturedAt.formatted(date: .abbreviated, time: .shortened))
          .font(.system(size: 11))
          .foregroundStyle(Color.cardTextMuted)
      }
      Spacer(minLength: 0)
    }
  }

  // MARK: - Field grid

  private var fieldGrid: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("KONTAKT").font(.system(size: 11, weight: .heavy)).kerning(0.8).foregroundStyle(Color.cardTextMuted)
      VStack(spacing: 0) {
        if let email = lead.email { row(icon: "envelope", value: email, action: { open("mailto:\(email)") }) }
        if let phone = lead.phone { row(icon: "phone",    value: phone, action: { open("tel:\(phone)") }) }
        if let country = lead.ipCountry {
          row(icon: "globe", value: "Aufgenommen aus \(country)", action: nil)
        }
      }
      .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(.black.opacity(0.04)))
    }
  }

  @ViewBuilder
  private func row(icon: String, value: String, action: (() -> Void)?) -> some View {
    Button {
      action?()
    } label: {
      HStack {
        Image(systemName: icon)
          .frame(width: 22)
          .foregroundStyle(Color.cardTextSecondary)
        Text(value)
          .foregroundStyle(.primary)
        Spacer()
        if action != nil {
          Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.cardTextMuted)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 12)
    }
    .buttonStyle(.plain)
    .disabled(action == nil)
  }

  // MARK: - Actions

  private var actions: some View {
    VStack(spacing: 10) {
      Button {
        if let url = URL(string: "https://atoll-os.com/contacts/card-inbox?lead=\(lead.id)") {
          UIApplication.shared.open(url)
        }
      } label: {
        Label("In Atoll Web öffnen", systemImage: "safari")
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(Color.primary, in: RoundedRectangle(cornerRadius: 12))
          .foregroundStyle(.white)
      }
      .buttonStyle(.plain)

      HStack {
        statusButton(String(localized: "Geöffnet"),   target: .opened)
        statusButton(String(localized: "Kontaktiert"), target: .contacted)
        statusButton(String(localized: "Archiviert"), target: .archived)
      }
    }
  }

  private func statusButton(_ label: String, target: LeadStatus) -> some View {
    Button {
      Task {
        await leadStore.updateStatus(id: lead.id, status: target)
        toast.show(String(localized: "Status: \(label)"), kind: .info)
      }
    } label: {
      Text(label)
        .font(.system(size: 13, weight: .semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(lead.status == target ? PillTone.beige.foreground : PillTone.beige.background, in: Capsule())
        .foregroundStyle(lead.status == target ? .white : PillTone.beige.foreground)
    }
    .buttonStyle(.plain)
  }

  private func open(_ url: String) {
    guard let u = URL(string: url) else { return }
    UIApplication.shared.open(u)
  }
}
