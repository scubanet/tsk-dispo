import SwiftUI
import SwiftData

struct SkillReviewSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    let student: Student
    let skill: PADISkill
    let context: SkillAssessmentContext

    @State private var selectedStatus: SkillStatus
    @State private var notes: String = ""

    init(student: Student, skill: PADISkill, context: SkillAssessmentContext) {
        self.student = student
        self.skill = skill
        self.context = context
        _selectedStatus = State(initialValue: student.currentStatus(for: skill.code))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(skill.title).font(.headline)
                    Text(skill.performanceStandard)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } header: {
                    Text(skill.code)
                }

                Section(L10n.currentLanguage == "de" ? "Status" : "Status") {
                    ForEach(SkillStatus.allCases, id: \.self) { s in
                        Button {
                            selectedStatus = s
                        } label: {
                            HStack {
                                SkillStatusBadge(status: s)
                                Spacer()
                                if s == selectedStatus {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(L10n.currentLanguage == "de" ? "Notiz" : "Notes") {
                    TextField(L10n.currentLanguage == "de" ? "Optional…" : "Optional…",
                              text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if !student.history(for: skill.code).isEmpty {
                    Section(L10n.currentLanguage == "de" ? "Historie" : "History") {
                        ForEach(student.history(for: skill.code), id: \.assessedOn) { c in
                            HStack {
                                SkillStatusBadge(status: c.statusEnum, compact: true)
                                Text(c.assessedOn.formatted(.dateTime.day().month().year()))
                                    .font(.system(size: 12))
                                Spacer()
                                if c.isSeedRecord {
                                    Text("seed")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                } else if let diveNum = c.dive?.number {
                                    Text("TG #\(diveNum)")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                } else if c.poolSession != nil {
                                    Text("Pool")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(student.fullName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.currentLanguage == "de" ? "Speichern" : "Save") {
                        ctx.setSkillStatus(selectedStatus, student: student, skillCode: skill.code,
                                           context: context, notes: notes)
                        dismiss()
                    }
                }
            }
        }
    }
}
