import SwiftUI
import SwiftData

struct PoolSessionCreateView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var slotCode = "CW1"
    @State private var courseType = "OWD"
    @State private var date = Date()
    @State private var durationMinutes: Int = 45
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var students: [Student] = []
    @State private var showingAssessment = false
    @State private var createdSession: PoolSession?

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.currentLanguage == "de" ? "Session" : "Session") {
                    Picker("Kurs", selection: $courseType) {
                        Text("OWD").tag("OWD")
                        Text("AOWD").tag("AOWD")
                    }
                    Picker(L10n.currentLanguage == "de" ? "Modul" : "Module", selection: $slotCode) {
                        ForEach(PADIStandards.shared.slots(for: courseType)
                                    .filter { $0.type == .pool }, id: \.code) { slot in
                            Text(slot.code).tag(slot.code)
                        }
                    }
                    DatePicker(L10n.currentLanguage == "de" ? "Datum" : "Date",
                               selection: $date)
                    Stepper("\(durationMinutes) min", value: $durationMinutes, in: 15...180, step: 5)
                    TextField(L10n.currentLanguage == "de" ? "Ort" : "Location", text: $location)
                }
                Section(L10n.currentLanguage == "de" ? "Schüler" : "Students") {
                    StudentPicker(selected: $students)
                }
                Section(L10n.currentLanguage == "de" ? "Notizen" : "Notes") {
                    TextField("", text: $notes, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Pool-Session" : "Pool Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.currentLanguage == "de" ? "Speichern" : "Save") {
                        let p = PoolSession()
                        p.slotCode = slotCode
                        p.courseType = courseType
                        p.date = date
                        p.durationMinutes = durationMinutes
                        p.location = location
                        p.notes = notes
                        p.students = students
                        ctx.insert(p)
                        try? ctx.save()
                        createdSession = p
                        showingAssessment = true
                    }
                    .disabled(students.isEmpty)
                }
            }
            .navigationDestination(isPresented: $showingAssessment) {
                if let session = createdSession {
                    PoolSessionDetailView(session: session)
                        .onDisappear { dismiss() }
                }
            }
        }
    }
}
