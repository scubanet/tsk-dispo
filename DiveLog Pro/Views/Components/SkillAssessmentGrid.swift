import SwiftUI
import SwiftData

struct SkillAssessmentGrid: View {
    @Environment(\.modelContext) private var ctx
    let student: Student
    let slotCode: String
    let courseType: String
    let context: SkillAssessmentContext
    var readonly: Bool = false
    var extraSkillCodes: [String] = []
    var onAddExtra: (() -> Void)? = nil
    var onRemoveExtra: ((String) -> Void)? = nil

    @State private var reviewing: PADISkill?
    @State private var flexExpanded = false

    private var slotSkills: [PADISkill] {
        PADIStandards.shared.skills(forSlot: slotCode, courseType: courseType)
    }

    private var flexSkills: [PADISkill] {
        PADIStandards.shared.flexibleSkills(for: courseType)
    }

    private var resolvedExtraSkills: [PADISkill] {
        extraSkillCodes.compactMap { PADIStandards.shared.skill(byCode: $0) }
    }

    private var allVisibleSkills: [PADISkill] {
        var all = slotSkills
        if flexExpanded { all += flexSkills }
        all += resolvedExtraSkills
        return all
    }

    private var progress: (done: Int, total: Int) {
        let all = allVisibleSkills
        let done = all.filter { student.currentStatus(for: $0.code) == .mastered }.count
        return (done, all.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            progressHeader

            // Slot skills
            ForEach(slotSkills, id: \.code) { skill in
                skillRow(skill)
            }

            // Flex skills (collapsible)
            if !flexSkills.isEmpty {
                flexSection
            }

            // Extra skills (cross-course)
            if !resolvedExtraSkills.isEmpty {
                extraSection
            }

            if !readonly {
                actionButtons
            }
        }
        .sheet(item: $reviewing) { skill in
            SkillReviewSheet(student: student, skill: skill, context: context)
        }
    }

    // MARK: - Progress Header

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
            ProgressView(value: Double(progress.done), total: max(1, Double(progress.total)))
                .tint(Color.appAccent)
        }
    }

    // MARK: - Flex Skills Section

    private var flexSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { flexExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: flexExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                    Text(L10n.currentLanguage == "de" ? "Flexible Skills" : "Flexible Skills")
                        .font(.system(size: 12, weight: .semibold))
                    Text("(\(flexSkills.count))")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.tertiary)
                    Spacer()
                    let flexDone = flexSkills.filter { student.currentStatus(for: $0.code) == .mastered }.count
                    if flexDone > 0 {
                        Text("\(flexDone)/\(flexSkills.count)")
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundStyle(Color.appSuccess)
                    }
                }
                .foregroundStyle(Color.appAccent)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if flexExpanded {
                ForEach(flexSkills, id: \.code) { skill in
                    skillRow(skill, tag: "FLEX")
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Extra Skills Section

    private var extraSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "plus.rectangle.on.rectangle")
                    .font(.system(size: 11, weight: .bold))
                Text(L10n.currentLanguage == "de" ? "Zusätzliche Skills" : "Extra Skills")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(Color.appEmphasis)
            .padding(.vertical, 6)

            ForEach(resolvedExtraSkills, id: \.code) { skill in
                skillRow(skill, tag: String(skill.code.prefix(while: { $0 != "." })), removable: true)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Skill Row

    private func skillRow(_ skill: PADISkill, tag: String? = nil, removable: Bool = false) -> some View {
        let status = student.currentStatus(for: skill.code)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(skill.code)
                        .font(.system(size: 10, weight: .bold).monospaced())
                        .foregroundStyle(.tertiary)
                    if let tag {
                        Text(tag)
                            .font(.system(size: 8, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(removable ? Color.appEmphasis.opacity(0.7) : Color.appAccent.opacity(0.7)))
                    }
                }
                Text(skill.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            if removable && !readonly {
                Button {
                    onRemoveExtra?(skill.code)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
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
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    for skill in allVisibleSkills {
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
                    for skill in allVisibleSkills where student.currentStatus(for: skill.code) == .notStarted {
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

            if onAddExtra != nil {
                Button {
                    onAddExtra?()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text(L10n.currentLanguage == "de" ? "Skill hinzufügen" : "Add Skill")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(Color.appEmphasis)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.appEmphasis.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appEmphasis.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5])))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }
}
