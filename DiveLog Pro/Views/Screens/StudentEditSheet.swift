import SwiftUI
import SwiftData

/// Full student edit sheet (Variante B): all captured fields editable plus a
/// destructive delete action with a cascade-warning confirmation dialog.
///
/// `@Bindable` means edits write straight through to the SwiftData model. We
/// still call `ctx.save()` on Done to flush the CloudKit mirror immediately,
/// and on Delete before dismissing so the caller's navigation can pop cleanly.
struct StudentEditSheet: View {
    @Bindable var student: Student
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    /// Called after the student is deleted so the parent view can pop its
    /// NavigationStack (otherwise we'd leave a zombie profile screen on top).
    var onDelete: (() -> Void)? = nil

    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.currentLanguage == "de" ? "Schüler" : "Student") {
                    TextField(L10n.currentLanguage == "de" ? "Vorname" : "First name",
                              text: $student.firstName)
                    TextField(L10n.currentLanguage == "de" ? "Nachname" : "Last name",
                              text: $student.lastName)
                    TextField(L10n.currentLanguage == "de" ? "Email" : "Email",
                              text: $student.email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("PADI eLearning ID", text: $student.padiELearningID)
                        .textInputAutocapitalization(.never)
                }

                Section(L10n.currentLanguage == "de" ? "Notizen" : "Notes") {
                    TextEditor(text: $student.notes)
                        .frame(minHeight: 80)
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label(L10n.currentLanguage == "de" ? "Schüler löschen" : "Delete student",
                              systemImage: "trash")
                    }
                }
            }
            .navigationTitle(L10n.currentLanguage == "de" ? "Schüler bearbeiten" : "Edit student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel") {
                        // SwiftData @Bindable writes are already persistent in memory.
                        // Rolling back requires explicit undo — acceptable trade-off
                        // for the simpler edit UX. Tapping the red X here just dismisses.
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.currentLanguage == "de" ? "Fertig" : "Done") {
                        try? ctx.save()
                        dismiss()
                    }
                    .disabled(student.firstName.isEmpty || student.lastName.isEmpty)
                }
            }
            .confirmationDialog(
                L10n.currentLanguage == "de"
                    ? "\(student.fullName) wirklich löschen?"
                    : "Delete \(student.fullName)?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(L10n.currentLanguage == "de" ? "Löschen" : "Delete", role: .destructive) {
                    deleteStudent()
                }
                Button(L10n.currentLanguage == "de" ? "Abbrechen" : "Cancel", role: .cancel) {}
            } message: {
                Text(L10n.currentLanguage == "de"
                     ? "Alle Skill-Bewertungen werden mitgelöscht. Tauchgänge und Pool-Sessions bleiben erhalten (nur die Schüler-Verknüpfung wird entfernt)."
                     : "All skill assessments will be deleted. Dives and pool sessions are kept (only the student link is removed).")
            }
        }
    }

    private func deleteStudent() {
        ctx.delete(student)
        try? ctx.save()
        dismiss()
        onDelete?()
    }
}
