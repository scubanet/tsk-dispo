import SwiftUI
import SwiftData

/// Per-student overview: overall mastery, per-slot breakdown, next slot hint,
/// "add historical progress" prompt for unseeded drop-ins.
struct StudentProfileView: View {
    @Bindable var student: Student
    @Environment(\.dismiss) private var dismiss
    @State private var courseType = "OWD"
    @State private var showingSeedSheet = false
    @State private var showingEditSheet = false

    private var progress: (mastered: Int, total: Int) {
        student.masteryProgress(courseType: courseType)
    }

    private var slots: [PADISlot] {
        PADIStandards.shared.slots(for: courseType)
    }

    private func slotProgress(_ slot: PADISlot) -> (done: Int, total: Int) {
        let done = slot.skills.filter { student.currentStatus(for: $0.code) == .mastered }.count
        return (done, slot.skills.count)
    }

    private var suggestedNextSlot: PADISlot? {
        slots.first { slot in
            slotProgress(slot).done < slot.skills.count
        }
    }

    /// Seed-pending marker: set by StudentPicker when the instructor chose "Teilweise"
    /// during inline add, deferring the actual skill-checklist to this screen.
    private var seedPending: Bool {
        UserDefaults.standard.bool(forKey: "seedPending.\(student.persistentModelID)")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                coursePicker
                overallProgress
                slotBreakdown
                if let next = suggestedNextSlot {
                    nextSlotCard(next)
                }
                seedPrompt
                contactSection
            }
            .padding()
        }
        .navigationTitle(student.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel(L10n.currentLanguage == "de" ? "Schüler bearbeiten" : "Edit student")
            }
        }
        .sheet(isPresented: $showingSeedSheet) {
            PriorMasterySeedSheet(
                student: student,
                courseType: courseType,
                upToSlotOrder: Int.max
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            StudentEditSheet(student: student, onDelete: {
                // Student deleted — pop back to the students list.
                dismiss()
            })
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 12) {
            Text(student.initials)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.appAccent))
            VStack(alignment: .leading, spacing: 4) {
                Text(student.fullName).font(.title3.bold())
                Text(L10n.currentLanguage == "de"
                     ? "Seit \(student.enrolledOn.formatted(.dateTime.day().month().year()))"
                     : "Since \(student.enrolledOn.formatted(.dateTime.day().month().year()))")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var coursePicker: some View {
        Picker("", selection: $courseType) {
            Text("OWD").tag("OWD")
            Text("AOWD").tag("AOWD")
        }
        .pickerStyle(.segmented)
    }

    private var overallProgress: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L10n.currentLanguage == "de" ? "Gesamt" : "Overall")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(progress.mastered) / \(progress.total)")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
            }
            ProgressView(value: Double(progress.mastered),
                         total: Double(max(1, progress.total)))
                .tint(Color.appAccent)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.surfaceCard))
    }

    private var slotBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(slots) { slot in
                let p = slotProgress(slot)
                NavigationLink {
                    slotDetail(slot)
                } label: {
                    HStack {
                        Text(slot.code)
                            .font(.system(size: 12, weight: .bold).monospaced())
                            .frame(width: 60, alignment: .leading)
                        ProgressView(value: Double(p.done),
                                     total: Double(max(1, p.total)))
                            .tint(p.done == p.total && p.total > 0 ? .green : Color.appAccent)
                        Text("\(p.done)/\(p.total)")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.surfaceCard))
    }

    @ViewBuilder
    private func slotDetail(_ slot: PADISlot) -> some View {
        ScrollView {
            SkillAssessmentGrid(
                student: student,
                slotCode: slot.code,
                courseType: courseType,
                context: .none,
                readonly: true
            )
            .padding()
        }
        .navigationTitle("\(slot.code) · \(slot.title)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func nextSlotCard(_ slot: PADISlot) -> some View {
        HStack {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(Color.appAccent)
            Text(L10n.currentLanguage == "de"
                 ? "Nächstes Modul: \(slot.code)"
                 : "Next module: \(slot.code)")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appAccent.opacity(0.1)))
    }

    /// Two paths into the seed sheet:
    ///   • "seed pending" marker from StudentPicker (inline partial choice)
    ///   • student has zero skillCompletions (true fresh drop-in)
    @ViewBuilder
    private var seedPrompt: some View {
        let noCompletions = (student.skillCompletions ?? []).isEmpty
        if noCompletions || seedPending {
            Button {
                showingSeedSheet = true
            } label: {
                Label(L10n.currentLanguage == "de"
                      ? "Historischen Fortschritt nachtragen"
                      : "Add historical progress",
                      systemImage: "clock.arrow.circlepath")
                    .font(.system(size: 13))
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var contactSection: some View {
        if !student.email.isEmpty || !student.padiELearningID.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                if !student.email.isEmpty {
                    Label(student.email, systemImage: "envelope")
                        .font(.system(size: 12))
                }
                if !student.padiELearningID.isEmpty {
                    Label(student.padiELearningID, systemImage: "person.text.rectangle")
                        .font(.system(size: 12))
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.surfaceCard))
        }
    }
}
