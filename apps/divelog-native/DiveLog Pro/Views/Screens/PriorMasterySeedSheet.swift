import SwiftUI
import SwiftData

/// Skill-by-skill checklist to seed prior mastery for a drop-in student.
/// Opened from either inline new-student flow (partial seed) or from the
/// Student Profile view when a "seed pending" marker is present.
struct PriorMasterySeedSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    let student: Student
    let courseType: String
    /// Seed only slots whose `.order` is strictly less than this value.
    /// Typically the order of the student's current slot.
    let upToSlotOrder: Int

    @State private var selected: Set<String> = []

    private var priorSlots: [PADISlot] {
        PADIStandards.shared.slots(for: courseType)
            .filter { $0.order < upToSlotOrder }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(priorSlots) { slot in
                    Section {
                        ForEach(slot.skills, id: \.code) { skill in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(skill.code)
                                        .font(.system(size: 10, weight: .bold).monospaced())
                                        .foregroundStyle(.tertiary)
                                    Text(skill.title)
                                        .font(.system(size: 14))
                                }
                                Spacer()
                                Image(systemName: selected.contains(skill.code)
                                      ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(selected.contains(skill.code)
                                                     ? Color.appAccent : .secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { toggle(skill.code) }
                        }
                    } header: {
                        HStack {
                            Text(slot.code).font(.system(size: 12, weight: .bold))
                            Text(slot.title)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Bisher gemeistert" : "Prior mastery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    // "Alle" / "Keine" convenience — flips between all prior skills and empty.
                    Button(allSelected ? (L10n.currentLanguage == "de" ? "Keine" : "None")
                                       : (L10n.currentLanguage == "de" ? "Alle"  : "All")) {
                        if allSelected {
                            selected.removeAll()
                        } else {
                            selected = Set(priorSlots.flatMap { $0.skills.map(\.code) })
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.currentLanguage == "de" ? "Übernehmen (\(selected.count))"
                                                      : "Apply (\(selected.count))") {
                        ctx.seedStudent(student, priorMastery: selected)
                        UserDefaults.standard.removeObject(forKey: "seedPending.\(student.persistentModelID)")
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }

    private var allSelected: Bool {
        let all = Set(priorSlots.flatMap { $0.skills.map(\.code) })
        return !all.isEmpty && selected == all
    }

    private func toggle(_ code: String) {
        if selected.contains(code) {
            selected.remove(code)
        } else {
            selected.insert(code)
        }
    }
}
