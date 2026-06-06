import SwiftUI

struct PreDivePreviewCard: View {
    let student: Student
    let slotCode: String
    let courseType: String

    @State private var expanded = false

    private var slotSkills: [PADISkill] {
        PADIStandards.shared.skills(forSlot: slotCode, courseType: courseType)
    }

    private var mastered: [PADISkill] {
        PADIStandards.shared.allSkills(for: courseType).filter {
            student.currentStatus(for: $0.code) == .mastered
        }
    }

    private var needsReview: [PADISkill] {
        PADIStandards.shared.allSkills(for: courseType).filter {
            student.currentStatus(for: $0.code) == .needsReview
        }
    }

    private var hasHistory: Bool {
        !(student.skillCompletions ?? []).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(Color.appAccent)
                    Text(L10n.currentLanguage == "de" ? "Pre-Dive-Check" : "Pre-Dive Check")
                        .font(.system(size: 13, weight: .semibold))
                    Text("· \(student.fullName)").font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                if !hasHistory {
                    noHistoryCard
                } else {
                    summaryLines
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.surfaceCard.opacity(0.6)))
    }

    private var noHistoryCard: some View {
        HStack {
            Image(systemName: "info.circle").foregroundStyle(.orange)
            Text(L10n.currentLanguage == "de"
                 ? "Keine Historie. Starte heute mit \(slotCode)."
                 : "No history. Start today at \(slotCode).")
                .font(.system(size: 12))
        }
    }

    private var summaryLines: some View {
        VStack(alignment: .leading, spacing: 6) {
            line(label: L10n.currentLanguage == "de" ? "Bereits gemeistert" : "Already mastered",
                 count: mastered.count, icon: "checkmark.seal.fill", color: .green)
            line(label: L10n.currentLanguage == "de" ? "Heute zu üben (\(slotCode))" : "To practice today (\(slotCode))",
                 count: slotSkills.filter { student.currentStatus(for: $0.code) != .mastered }.count,
                 icon: "target", color: .blue)
            if !needsReview.isEmpty {
                line(label: L10n.currentLanguage == "de" ? "Wdh. nötig" : "Needs review",
                     count: needsReview.count, icon: "exclamationmark.triangle.fill", color: .red)
            }
        }
    }

    private func line(label: String, count: Int, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(label).font(.system(size: 12))
            Spacer()
            Text("\(count)").font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(color)
        }
    }
}
