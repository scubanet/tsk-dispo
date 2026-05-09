import SwiftUI
import SwiftData

/// Drop-In Magic entry: pick active students (14-day window) + inline add new,
/// then hand off to DiveFormView or PoolSessionCreateView.
/// Smart pre-fill of selected students + next slot happens in Task 28.
struct QuickLogView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var allStudents: [Student]

    @State private var selectedStudents: [Student] = []
    @State private var mode: Mode = .dive
    @State private var showingDiveCreate = false
    @State private var showingPoolCreate = false
    @State private var showingNewStudent = false

    enum Mode: Hashable { case dive, pool }

    /// Students with activity (dive or pool) in the last 14 days, most-recent first.
    private var activeStudents: [Student] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        return allStudents
            .filter { ($0.lastActivityDate ?? .distantPast) >= cutoff }
            .sorted { ($0.lastActivityDate ?? .distantPast) > ($1.lastActivityDate ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            List {
                studentsSection
                modeSection
            }
            .navigationTitle("Quick-Log")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.currentLanguage == "de" ? "Weiter" : "Next") {
                        switch mode {
                        case .dive: showingDiveCreate = true
                        case .pool: showingPoolCreate = true
                        }
                    }
                    .disabled(selectedStudents.isEmpty)
                }
            }
            .sheet(isPresented: $showingNewStudent) {
                NewStudentSheet { s in
                    ctx.insert(s)
                    try? ctx.save()
                    selectedStudents.append(s)
                }
            }
            .sheet(isPresented: $showingDiveCreate) {
                // Pre-fill: selected students + inferred course type from the
                // first student's first logged dive (fallback OWD). The form's
                // own suggestedNextSlot picks the best starting module.
                DiveFormView(
                    mode: .new,
                    prefillStudents: selectedStudents,
                    prefillCourseType: selectedStudents.first?.dives?.first?.courseType ?? "OWD"
                )
            }
            .sheet(isPresented: $showingPoolCreate) {
                PoolSessionCreateView(
                    prefillStudents: selectedStudents,
                    prefillCourseType: "OWD"
                )
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var studentsSection: some View {
        Section(L10n.currentLanguage == "de"
                ? "Aktive Schüler (14 Tage)"
                : "Active students (14 days)") {
            if activeStudents.isEmpty {
                Text(L10n.currentLanguage == "de"
                     ? "Keine aktiven Schüler. Starte mit Drop-In."
                     : "No active students. Start with a drop-in.")
                    .foregroundStyle(.secondary)
            }
            ForEach(activeStudents) { s in
                studentRow(s)
            }
            Button {
                showingNewStudent = true
            } label: {
                Label(L10n.currentLanguage == "de"
                      ? "Neuer Schüler (Drop-In)"
                      : "New student (drop-in)",
                      systemImage: "person.badge.plus")
            }
        }
    }

    private func studentRow(_ s: Student) -> some View {
        let isSelected = selectedStudents.contains { $0.id == s.id }
        return Button {
            if isSelected {
                selectedStudents.removeAll { $0.id == s.id }
            } else {
                selectedStudents.append(s)
            }
        } label: {
            HStack {
                Text(s.initials)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.appAccent))
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.fullName).font(.system(size: 14))
                    if let last = s.lastActivityDate {
                        Text(L10n.currentLanguage == "de"
                             ? "Zuletzt: \(last.formatted(.dateTime.day().month()))"
                             : "Last: \(last.formatted(.dateTime.day().month()))")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var modeSection: some View {
        Section(L10n.currentLanguage == "de" ? "Typ" : "Type") {
            Picker("", selection: $mode) {
                Text(L10n.currentLanguage == "de" ? "Tauchgang" : "Dive").tag(Mode.dive)
                Text("Pool").tag(Mode.pool)
            }
            .pickerStyle(.segmented)
        }
    }
}
