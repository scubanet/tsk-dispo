import SwiftUI
import AtollDesign

/// Editor for a `Card`. Opens as a sheet — used for both "new" and "edit".
///
/// The flow:
///   • UI binds to a local `@State draft` so mutations don't leak until Save.
///   • The top of the sheet shows a live `BizCardView` preview that updates
///     as the user types / picks theme / toggles specialties.
///   • Save → `CardStore.upsert(draft)`. New cards get a fresh UUID.
///   • Delete → confirmation alert → `CardStore.delete`.
struct CardEditorSheet: View {
  @Environment(\.dismiss)        private var dismiss
  @Environment(CardStore.self)   private var cardStore
  @Environment(LeadStore.self)   private var leadStore
  @Environment(ToastCenter.self) private var toast

  /// Pass `nil` to create a new card.
  let card: Card?

  @State private var draft: Card
  @State private var showDeleteConfirm = false
  @State private var saving = false

  init(card: Card?) {
    self.card = card
    _draft = State(initialValue: card ?? Self.blankCard())
  }

  private static func blankCard() -> Card {
    Card(
      id: UUID(),
      personId: MockSeed.dominik.id,                   // single-person app for now
      slug: "neue-karte-\(Int.random(in: 1000...9999))",
      title: "Neue Karte",
      subtitle: nil,
      badge: nil,
      theme: CardTheme(preset: .courseDirector),
      diveProfile: DiveProfile(),
      fieldVisibility: .standard,
      isDefault: false,
      isActive: true,
      createdAt: .now,
      updatedAt: .now
    )
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          preview
          basicsSection
          themeSection
          diveSection
          visibilitySection
          if card != nil {
            deleteSection
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
      }
      .background(Color.cardPageBackground)
      .navigationTitle(card == nil ? "Neue Karte" : "Karte bearbeiten")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading)  { Button("Abbrechen") { dismiss() } }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Speichern", action: save)
            .bold()
            .disabled(saving)
        }
      }
      .alert("Karte löschen?", isPresented: $showDeleteConfirm) {
        Button("Löschen", role: .destructive) { delete() }
        Button("Abbrechen", role: .cancel) {}
      } message: {
        Text("Die Karte „\(draft.title)“ wird permanent entfernt. Bestehende Scans und Leads bleiben erhalten.")
      }
    }
  }

  // MARK: - Live preview

  private var preview: some View {
    BizCardView(
      card: draft,
      person: MockSeed.dominik,
      scansCount: MockSeed.analytics(for: draft.id, range: .thirtyDays).totalScans,
      leadsCount: leadStore.leads.filter { $0.cardId == draft.id }.count,
      fillWidth: true
    )
  }

  // MARK: - Sections

  private var basicsSection: some View {
    EditorSection(title: "GRUNDDATEN") {
      EditorField("Titel", text: Binding(
        get: { draft.title },
        set: { draft.title = $0 }
      ))
      EditorField("Untertitel", text: Binding(
        get: { draft.subtitle ?? "" },
        set: { draft.subtitle = $0.isEmpty ? nil : $0 }
      ))
      EditorField("Badge (z.B. PADI CD)", text: Binding(
        get: { draft.badge ?? "" },
        set: { draft.badge = $0.isEmpty ? nil : $0.uppercased() }
      ))
      EditorField("Slug (URL)", text: Binding(
        get: { draft.slug },
        set: { draft.slug = $0.lowercased().replacingOccurrences(of: " ", with: "-") }
      ), monospaced: true,
         caption: "atoll-os.com/c/\(draft.slug)")
      Toggle("Als Default-Karte", isOn: Binding(
        get: { draft.isDefault },
        set: { draft.isDefault = $0 }
      ))
      .tint(Color.cardPillBlueText)
      .padding(.vertical, 4)
    }
  }

  private var themeSection: some View {
    EditorSection(title: "THEME") {
      ThemePicker(preset: Binding(
        get: { draft.theme.preset },
        set: { draft.theme = CardTheme(preset: $0) }
      ))
    }
  }

  private var diveSection: some View {
    EditorSection(title: "TAUCH-PROFIL") {
      EditorField("PADI Member Number", text: Binding(
        get: { draft.diveProfile?.padiMemberNumber ?? "" },
        set: { newValue in
          mutateDive { $0.padiMemberNumber = newValue.isEmpty ? nil : newValue }
        }
      ), monospaced: true)
      EditorField("Total Dives", text: Binding(
        get: { draft.diveProfile?.totalDives.map(String.init) ?? "" },
        set: { newValue in
          mutateDive { $0.totalDives = Int(newValue) }
        }
      ))
      EditorField("Tauche seit (Jahr)", text: Binding(
        get: { draft.diveProfile?.sinceYear.map(String.init) ?? "" },
        set: { newValue in
          mutateDive { $0.sinceYear = Int(newValue) }
        }
      ))
      Picker("Instructor Level", selection: Binding(
        get: { draft.diveProfile?.instructorLevel },
        set: { newValue in mutateDive { $0.instructorLevel = newValue } }
      )) {
        Text("—").tag(InstructorLevel?.none)
        ForEach(InstructorLevel.allCases) { level in
          Text(level.rawValue).tag(InstructorLevel?.some(level))
        }
      }
      .pickerStyle(.menu)
      .padding(.vertical, 4)

      SpecialtyGrid(selected: Binding(
        get: { Set(draft.diveProfile?.specialties ?? []) },
        set: { newValue in mutateDive { $0.specialties = Array(newValue).sorted() } }
      ))
    }
  }

  private var visibilitySection: some View {
    EditorSection(title: "WAS AUF DER PUBLIC-PAGE SICHTBAR IST") {
      visibilityToggle("E-Mail", keyPath: \.email)
      visibilityToggle("Telefon", keyPath: \.phone)
      visibilityToggle("WhatsApp", keyPath: \.whatsapp)
      visibilityToggle("Instagram", keyPath: \.instagram)
      visibilityToggle("LinkedIn", keyPath: \.linkedin)
      visibilityToggle("Website", keyPath: \.website)
      visibilityToggle("Tauch-Stats (Dives, Specialties)", keyPath: \.diveStats)
    }
  }

  private var deleteSection: some View {
    Button(role: .destructive) {
      showDeleteConfirm = true
    } label: {
      Label("Karte löschen", systemImage: "trash")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.cardPillRose, in: RoundedRectangle(cornerRadius: 12))
        .foregroundStyle(Color.cardPillRoseText)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Helpers

  private func mutateDive(_ block: (inout DiveProfile) -> Void) {
    var profile = draft.diveProfile ?? DiveProfile()
    block(&profile)
    draft.diveProfile = profile
  }

  private func visibilityToggle(_ label: String, keyPath: WritableKeyPath<FieldVisibility, Bool>) -> some View {
    Toggle(label, isOn: Binding(
      get: { draft.fieldVisibility[keyPath: keyPath] },
      set: { newValue in draft.fieldVisibility[keyPath: keyPath] = newValue }
    ))
    .tint(Color.cardPillBlueText)
    .padding(.vertical, 2)
  }

  private func save() {
    saving = true
    draft.updatedAt = .now
    Task {
      await cardStore.upsert(draft)
      if draft.isDefault {
        await cardStore.setDefault(id: draft.id)
      }
      toast.show(card == nil ? "Karte erstellt" : "Karte gespeichert", kind: .success)
      saving = false
      dismiss()
    }
  }

  private func delete() {
    Task {
      await cardStore.delete(id: draft.id)
      toast.show("Karte gelöscht", kind: .info)
      dismiss()
    }
  }
}

// MARK: - Editor primitives

private struct EditorSection<Content: View>: View {
  let title: String
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.system(size: 11, weight: .heavy))
        .kerning(0.8)
        .foregroundStyle(Color.cardTextMuted)
      VStack(alignment: .leading, spacing: 10) {
        content()
      }
      .padding(14)
      .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(.black.opacity(0.04)))
    }
  }
}

private struct EditorField: View {
  let label: String
  @Binding var text: String
  var monospaced: Bool = false
  var caption: String? = nil

  init(_ label: String, text: Binding<String>, monospaced: Bool = false, caption: String? = nil) {
    self.label = label
    self._text = text
    self.monospaced = monospaced
    self.caption = caption
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.cardTextMuted)
      TextField("", text: $text)
        .font(monospaced ? .system(.body, design: .monospaced) : .body)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.cardSoftBackground, in: RoundedRectangle(cornerRadius: 8))
      if let caption {
        Text(caption)
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(Color.cardTextMuted)
      }
    }
  }
}

// MARK: - Theme Picker

private struct ThemePicker: View {
  @Binding var preset: ThemePreset

  var body: some View {
    LazyVGrid(columns: [.init(.flexible(), spacing: 8), .init(.flexible(), spacing: 8)],
              spacing: 8) {
      ForEach(ThemePreset.allCases.filter { $0 != .custom }) { p in
        Button {
          preset = p
        } label: {
          ZStack(alignment: .bottomLeading) {
            LinearGradient.persona(CardTheme(preset: p))
            VStack(alignment: .leading, spacing: 2) {
              Text(p.defaultLabel)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
              if preset == p {
                HStack(spacing: 4) {
                  Image(systemName: "checkmark.circle.fill").font(.system(size: 11))
                  Text("AKTIV")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.6)
                }
                .foregroundStyle(.white.opacity(0.9))
              }
            }
            .padding(10)
          }
          .frame(height: 64)
          .clipShape(RoundedRectangle(cornerRadius: 12))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(preset == p ? .white : .clear, lineWidth: 3)
          )
          .shadow(color: .black.opacity(preset == p ? 0.18 : 0.08), radius: preset == p ? 8 : 4, y: 2)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

// MARK: - Specialty Grid

private struct SpecialtyGrid: View {
  @Binding var selected: Set<String>

  /// Loaded from the Atoll OS master catalog via `SpecialtyCatalogService`.
  /// In mock mode the service returns a curated demo set; in live mode it
  /// returns only specialties the instructor actually holds a permit for
  /// (via `instructor_skills`). See SpecialtyCatalogService.swift.
  @State private var specialties: [SpecialtyCatalogService.Specialty] = []
  @State private var loadState: LoadState = .loading

  private enum LoadState { case loading, ready, failed(String) }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("SPEZIALITÄTEN")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color.cardTextMuted)

      switch loadState {
      case .loading:
        HStack(spacing: 8) {
          ProgressView().controlSize(.small)
          Text("Lade Spezialitäten …")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)

      case .failed(let msg):
        Text("Konnte nicht laden: \(msg)")
          .font(.system(size: 12))
          .foregroundStyle(Color.cardPillRoseText)

      case .ready where specialties.isEmpty:
        Text("Keine Specialty-Permits hinterlegt. Verwalte deine Skills in der Atoll-OS-Hauptapp.")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)

      case .ready:
        // Specialty pills grouped: regular tier first (rendered as the
        // existing blue chips), then SPEI tier (subtly distinguished via
        // a "T" trailer + slightly different tone). Both store the same
        // label string on the card.
        FlowLayout(spacing: 6) {
          ForEach(specialties) { spec in
            pill(for: spec)
          }
        }
      }
    }
    .task {
      await load()
    }
  }

  @ViewBuilder
  private func pill(for spec: SpecialtyCatalogService.Specialty) -> some View {
    let isOn = selected.contains(spec.label)
    Button {
      if isOn { selected.remove(spec.label) } else { selected.insert(spec.label) }
    } label: {
      HStack(spacing: 4) {
        Text(spec.label)
        if spec.isTrainerLevel {
          // Tiny "T" badge for SPEI (Trainer) credentials so the user
          // can tell at a glance which pills are trainer-level.
          Text("T")
            .font(.system(size: 9, weight: .black))
            .foregroundStyle(isOn ? Color.white.opacity(0.85) : Color.cardPillPurpleText)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
              isOn ? Color.white.opacity(0.2) : Color.cardPillPurple,
              in: Capsule()
            )
        }
      }
      .font(.system(size: 13, weight: isOn ? .semibold : .medium))
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(isOn ? Color.cardPillBlueText : Color.cardSoftBackground, in: Capsule())
      .foregroundStyle(isOn ? Color.white : Color.primary)
    }
    .buttonStyle(.plain)
  }

  private func load() async {
    do {
      let items = try await SpecialtyCatalogService.shared.fetchUserSpecialties()
      specialties = items
      loadState = .ready
    } catch {
      loadState = .failed(error.localizedDescription)
    }
  }
}
