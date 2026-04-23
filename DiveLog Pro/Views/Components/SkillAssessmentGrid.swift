import SwiftUI
import SwiftData

struct SkillAssessmentGrid: View {
    @Environment(\.modelContext) private var ctx
    let student: Student
    let slotCode: String
    let courseType: String
    let context: SkillAssessmentContext
    var readonly: Bool = false

    @State private var reviewing: PADISkill?

    private var skills: [PADISkill] {
        PADIStandards.shared.skills(forSlot: slotCode, courseType: courseType)
    }

    private var progress: (done: Int, total: Int) {
        let done = skills.filter { student.currentStatus(for: $0.code) == .mastered }.count
        return (done, skills.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            progressHeader
            ForEach(skills, id: \.code) { skill in
                skillRow(skill)
            }
            if !readonly { bulkActions }
        }
        .sheet(item: $reviewing) { skill in
            SkillReviewSheet(student: student, skill: skill, context: context)
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L10n.currentLanguage == "de" ? "Fortschritt" : "Progress")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(progress.done)/\(progress.total)")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.appAccent)
            }
            ProgressView(value: Double(progress.done), total: Double(progress.total))
                .tint(Color.appAccent)
        }
    }

    private func skillRow(_ skill: PADISkill) -> some View {
        let status = student.currentStatus(for: skill.code)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.code)
                    .font(.system(size: 10, weight: .bold).monospaced())
                    .foregroundStyle(.tertiary)
                Text(skill.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            SkillStatusBadge(status: status, compact: false)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.surfaceCard))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            guard !readonly else { return }
            ctx.cycleSkill(student: student, skillCode: skill.code, context: context)
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            guard !readonly else { return }
            reviewing = skill
        }
        .swipeActions(edge: .trailing) {
            if !readonly {
                Button(role: .destructive) {
                    ctx.setSkillStatus(.notStarted, student: student, skillCode: skill.code,
                                       context: context)
                } label: {
                    Label(L10n.currentLanguage == "de" ? "Reset" : "Reset",
                          systemImage: "arrow.counterclockwise")
                }
            }
        }
    }

    private var bulkActions: some View {
        HStack(spacing: 8) {
            Button {
                for skill in skills {
                    ctx.setSkillStatus(.mastered, student: student, skillCode: skill.code,
                                       context: context)
                }
            } label: {
                Label(L10n.currentLanguage == "de" ? "Alle auf mastered" : "All to mastered",
                      systemImage: "checkmark.seal.fill")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .tint(.green)

            Button {
                for skill in skills where student.currentStatus(for: skill.code) == .notStarted {
                    ctx.setSkillStatus(.introduced, student: student, skillCode: skill.code,
                                       context: context)
                }
            } label: {
                Label(L10n.currentLanguage == "de" ? "Offene auf introduced" : "Pending to introduced",
                      systemImage: "arrow.right.circle")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
        .padding(.top, 8)
    }
}
