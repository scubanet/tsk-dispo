import SwiftUI
import SwiftData

struct StudentPicker: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Student.enrolledOn, order: .reverse) private var allStudents: [Student]
    @Binding var selected: [Student]
    var allowCreate: Bool = true

    @State private var showingPicker = false
    @State private var showingNewStudentSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(selected) { student in
                HStack {
                    avatar(student)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(student.fullName).font(.system(size: 14, weight: .semibold))
                        if !student.padiELearningID.isEmpty {
                            Text(student.padiELearningID)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    Button {
                        selected.removeAll { $0.id == student.id }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.surfaceCard))
            }
            Button {
                showingPicker = true
            } label: {
                Label(L10n.currentLanguage == "de" ? "Schüler hinzufügen" : "Add student",
                      systemImage: "person.badge.plus")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
        }
        .sheet(isPresented: $showingPicker) {
            pickerSheet
        }
        .sheet(isPresented: $showingNewStudentSheet) {
            NewStudentSheet { newStudent in
                ctx.insert(newStudent)
                try? ctx.save()
                selected.append(newStudent)
            }
        }
    }

    private func avatar(_ s: Student) -> some View {
        Text(s.initials)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Circle().fill(Color.appAccent))
    }

    @ViewBuilder
    private var pickerSheet: some View {
        NavigationStack {
            List {
                ForEach(allStudents) { s in
                    let isSelected = selected.contains { $0.id == s.id }
                    Button {
                        if isSelected {
                            selected.removeAll { $0.id == s.id }
                        } else {
                            selected.append(s)
                        }
                    } label: {
                        HStack {
                            avatar(s)
                            Text(s.fullName)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Schüler wählen" : "Select student")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Fertig" : "Done") { showingPicker = false }
                }
                if allowCreate {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingPicker = false
                            showingNewStudentSheet = true
                        } label: {
                            Label(L10n.currentLanguage == "de" ? "Neu" : "New", systemImage: "plus")
                        }
                    }
                }
            }
        }
    }
}

// Inline quick-create sheet (name + optional course + seed)
struct NewStudentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    let onCreate: (Student) -> Void

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var padiID = ""
    @State private var courseType = "OWD"
    @State private var courseSlot = "OW1"
    @State private var seedChoice: SeedChoice = .skip
    @State private var showingSeedSheet = false

    enum SeedChoice: Hashable { case allMastered, partial, skip }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.currentLanguage == "de" ? "Schüler" : "Student") {
                    TextField(L10n.currentLanguage == "de" ? "Vorname *" : "First name *",
                              text: $firstName)
                    TextField(L10n.currentLanguage == "de" ? "Nachname *" : "Last name *",
                              text: $lastName)
                    TextField(L10n.currentLanguage == "de" ? "Email (optional)" : "Email (optional)",
                              text: $email)
                        .keyboardType(.emailAddress)
                    TextField("PADI eLearning ID (optional)", text: $padiID)
                }
                Section(L10n.currentLanguage == "de" ? "Kurs" : "Course") {
                    Picker("Kurs", selection: $courseType) {
                        Text("OWD").tag("OWD")
                        Text("AOWD").tag("AOWD")
                    }
                    Picker(L10n.currentLanguage == "de" ? "Aktueller Slot" : "Current slot",
                           selection: $courseSlot) {
                        ForEach(PADIStandards.shared.slots(for: courseType), id: \.code) { slot in
                            Text(slot.code).tag(slot.code)
                        }
                    }
                }
                Section(L10n.currentLanguage == "de" ? "Vorherige Slots?" : "Prior slots?") {
                    Picker("Seed", selection: $seedChoice) {
                        Text(L10n.currentLanguage == "de" ? "Alles gemeistert" : "All mastered")
                            .tag(SeedChoice.allMastered)
                        Text(L10n.currentLanguage == "de" ? "Teilweise…" : "Partial…")
                            .tag(SeedChoice.partial)
                        Text(L10n.currentLanguage == "de" ? "Überspringen" : "Skip")
                            .tag(SeedChoice.skip)
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Neuer Schüler" : "New student")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.currentLanguage == "de" ? "Anlegen" : "Create") {
                        let s = Student()
                        s.firstName = firstName
                        s.lastName = lastName
                        s.email = email
                        s.padiELearningID = padiID
                        handleSeed(for: s)
                        onCreate(s)
                        dismiss()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty)
                }
            }
            .sheet(isPresented: $showingSeedSheet) {
                // Forward declaration — see Task 25 (PriorMasterySeedSheet)
            }
        }
    }

    private func handleSeed(for student: Student) {
        switch seedChoice {
        case .allMastered:
            // Seed everything before currentSlot
            let allSlots = PADIStandards.shared.slots(for: courseType)
            let currentOrder = allSlots.first { $0.code == courseSlot }?.order ?? 0
            let prior = allSlots.filter { $0.order < currentOrder }
            let codes = Set(prior.flatMap { $0.skills.map(\.code) })
            ctx.seedStudent(student, priorMastery: codes)
        case .partial:
            // Partial seed sheet opens after create in DiveCreate flow — for inline new-student
            // here we skip the partial-picker UI and just keep it unseeded. A follow-up seed can
            // be triggered from the Student Profile view.
            break
        case .skip:
            break
        }
    }
}
