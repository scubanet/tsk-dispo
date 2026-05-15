import SwiftUI
import AtollCore

struct IntakeSheet: View {
  let participant: CourseParticipant
  let user: CurrentUser
  let store: IntakeStore
  let onSaved: () -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var medical: Bool = false
  @State private var liability: Bool = false
  @State private var safeDiving: Bool = false
  @State private var notes: String = ""

  @State private var saving = false
  @State private var saveError: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle(isOn: $medical) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Medical Statement").font(.body)
              Text("unterschrieben")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          Toggle(isOn: $liability) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Liability Release").font(.body)
              Text("PADI-Formular unterschrieben")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          Toggle(isOn: $safeDiving) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Safe Diving Procedures").font(.body)
              Text("PADI-Formular unterschrieben")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        } header: {
          Text("Pre-Dive-Checks")
        }

        Section("Notiz") {
          TextField("Optional", text: $notes, axis: .vertical)
            .lineLimit(2...6)
        }

        if let error = saveError {
          Section {
            Text(error)
              .font(.caption)
              .foregroundStyle(.red)
          }
        }
      }
      .navigationTitle(participant.student?.displayName ?? "Pre-Dive-Check")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(saving ? "Speichert…" : "Speichern") {
            Task { await save() }
          }
          .disabled(saving)
        }
      }
    }
    .task { loadExisting() }
  }

  private func loadExisting() {
    if let existing = store.intakesByParticipant[participant.id] {
      medical = existing.medicalSigned
      liability = existing.liabilitySigned
      safeDiving = existing.safeDivingSigned
      notes = existing.notes ?? ""
    }
  }

  private func save() async {
    saving = true
    saveError = nil
    defer { saving = false }
    do {
      try await store.save(
        participantId: participant.id,
        medical: medical,
        liability: liability,
        safeDiving: safeDiving,
        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
        checkedById: user.instructorId
      )
      onSaved()
      dismiss()
    } catch {
      saveError = error.localizedDescription
    }
  }
}
