import SwiftUI
import PhotosUI
import AtollCore

/// Modal settings — account, default persona, notifications, theme, about.
/// Kept small & list-based until a dedicated `Settings` tab is justified.
struct SettingsView: View {
  @Environment(\.dismiss)            private var dismiss
  @Environment(AuthState.self)       private var auth
  @Environment(CardStore.self)       private var cardStore
  @Environment(ToastCenter.self)     private var toast

  // Avatar-upload state — local to the sheet, no global store needed yet.
  @State private var pickedItem: PhotosPickerItem?
  @State private var previewImage: UIImage?
  @State private var existingAvatarUrl: URL?
  @State private var uploading = false

  var body: some View {
    NavigationStack {
      Form {
        logoHeaderSection
        profilePhotoSection
        accountSection
        defaultPersonaSection
        notificationsSection
        themeSection
        SyncStatusSection()
        aboutSection
      }
      .scrollContentBackground(.hidden)
      .background(Color.cardPageBackground)
      .navigationTitle("Settings")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(String(localized: "Fertig")) { dismiss() }
        }
      }
    }
  }

  // MARK: - Sections

  private var logoHeaderSection: some View {
    Section {
      HStack {
        Spacer()
        VStack(spacing: 8) {
          AtollCardLogo(size: 64)
          Text("AtollCard")
            .font(.system(size: 22, weight: .bold))
            .tracking(-0.3)
          Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .padding(.vertical, 12)
      .listRowBackground(Color.clear)
    }
  }

  private var profilePhotoSection: some View {
    Section("Profilfoto") {
      HStack(spacing: 16) {
        // Stack: picked > already-uploaded > initials fallback.
        Group {
          if let img = previewImage {
            Image(uiImage: img)
              .resizable()
              .scaledToFill()
          } else if let url = existingAvatarUrl {
            AsyncImage(url: url) { phase in
              switch phase {
              case .success(let image):
                image.resizable().scaledToFill()
              case .empty, .failure:
                Avatar(
                  initials: MockSeed.dominik.initials,
                  colorHex: MockSeed.dominik.avatarColorHex
                )
              @unknown default:
                Avatar(
                  initials: MockSeed.dominik.initials,
                  colorHex: MockSeed.dominik.avatarColorHex
                )
              }
            }
          } else {
            Avatar(
              initials: MockSeed.dominik.initials,
              colorHex: MockSeed.dominik.avatarColorHex
            )
          }
        }
        .frame(width: 60, height: 60)
        .clipShape(Circle())

        VStack(alignment: .leading, spacing: 4) {
          Text("Auf der öffentlichen Karte")
            .font(.system(size: 13, weight: .semibold))
          Text("Quadrat, mind. 512×512 px")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      .listRowBackground(Color.clear)

      PhotosPicker(
        selection: $pickedItem,
        matching: .images,
        photoLibrary: .shared()
      ) {
        Label(
          previewImage == nil ? "Foto auswählen" : "Anderes Foto",
          systemImage: "photo.on.rectangle"
        )
      }

      if previewImage != nil {
        Button {
          guard let img = previewImage else { return }
          uploading = true
          Task {
            do {
              let url = try await AvatarUploadService.shared.upload(image: img)
              toast.show(String(localized: "Profilfoto gespeichert"), kind: .success)
              // Promote the preview to the persisted slot so the user sees
              // their photo stay in place (instead of snapping back to the
              // initials placeholder).
              existingAvatarUrl = URL(string: url)
              previewImage = nil
              pickedItem   = nil
            } catch {
              toast.show(String(localized: "Upload fehlgeschlagen: \(error.localizedDescription)"), kind: .error)
            }
            uploading = false
          }
        } label: {
          HStack {
            if uploading {
              ProgressView().controlSize(.small)
              Text("Lade hoch …")
            } else {
              Label("Hochladen", systemImage: "arrow.up.circle.fill")
            }
          }
        }
        .disabled(uploading)
      }
    }
    .onChange(of: pickedItem) { _, newValue in
      guard let newValue else { return }
      Task {
        if let data = try? await newValue.loadTransferable(type: Data.self),
           let img  = UIImage(data: data) {
          previewImage = img
        }
      }
    }
    .task {
      // Load whatever portrait the user already has saved (so the section
      // doesn't lie about state). No-op in mock mode.
      guard !Config.useMockData else { return }
      if let url = try? await AvatarUploadService.shared.fetchCurrentAvatarUrl() {
        existingAvatarUrl = url
      }
    }
  }

  private var accountSection: some View {
    Section("Account") {
      if Config.useMockData {
        LabeledContent("Modus") {
          Text("Mock — Demo-Daten").foregroundStyle(.secondary)
        }
      } else if case .signedIn(let user) = auth.status {
        LabeledContent("Eingeloggt als") {
          Text(user.email ?? "—").foregroundStyle(.secondary)
        }
        Button(role: .destructive) {
          Task {
            await auth.signOut()
            dismiss()
          }
        } label: {
          Label("Abmelden", systemImage: "rectangle.portrait.and.arrow.right")
        }
      } else {
        Text("Nicht eingeloggt")
      }
    }
  }

  private var defaultPersonaSection: some View {
    Section("Default Persona") {
      ForEach(cardStore.cards) { card in
        Button {
          Task {
            await cardStore.setDefault(id: card.id)
            toast.show(String(localized: "Default-Karte: \(card.title)"), kind: .info)
          }
        } label: {
          HStack {
            Text(card.title)
            Spacer()
            if card.isDefault {
              Image(systemName: "checkmark")
                .foregroundStyle(Color.cardPillBlueText)
            }
          }
        }
      }
    }
  }

  private var notificationsSection: some View {
    Section("Notifications") {
      Toggle("Push bei neuen Leads", isOn: .constant(true))
      Toggle("Tägliche Zusammenfassung", isOn: .constant(false))
    }
  }

  private var themeSection: some View {
    Section("Aussehen") {
      Picker("App-Theme", selection: .constant("system")) {
        Text("System").tag("system")
        Text("Hell").tag("light")
        Text("Dunkel").tag("dark")
      }
    }
  }

  private var aboutSection: some View {
    Section("Über") {
      LabeledContent("Version") {
        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
          .foregroundStyle(.secondary)
      }
      LabeledContent("Backend") {
        Text(Config.tenantName).foregroundStyle(.secondary)
      }
      Link(destination: URL(string: "https://atoll-os.com")!) {
        Label("Atoll OS Website", systemImage: "globe")
      }
    }
  }
}
