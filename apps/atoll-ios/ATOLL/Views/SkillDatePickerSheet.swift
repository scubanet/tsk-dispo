import SwiftUI
import AtollCore

/// Sheet zum Setzen des Datums für einen Skill (für alle Records einer Skill-Reihe gleichzeitig).
struct SkillDatePickerSheet: View {
  let skill: SkillDefinition
  let currentDate: String
  let onSave: (String) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var selectedDate: Date

  init(skill: SkillDefinition, currentDate: String, onSave: @escaping (String) -> Void) {
    self.skill = skill
    self.currentDate = currentDate
    self.onSave = onSave
    let formatter = Self.isoDateFormatter
    _selectedDate = State(initialValue: formatter.date(from: currentDate) ?? Date())
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        DatePicker(
          "Datum",
          selection: $selectedDate,
          displayedComponents: .date
        )
        .datePickerStyle(.graphical)
        .padding(.horizontal)
        .padding(.top, 8)

        Spacer()

        Text("Das Datum gilt für alle Schüler dieser Skill-Reihe in diesem Kurs.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal)
          .padding(.bottom, 12)
      }
      .navigationTitle(skill.label)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Speichern") {
            onSave(Self.isoDateFormatter.string(from: selectedDate))
            dismiss()
          }
        }
      }
      .presentationDetents([.medium, .large])
    }
  }

  private static let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Europe/Zurich")
    return f
  }()
}
