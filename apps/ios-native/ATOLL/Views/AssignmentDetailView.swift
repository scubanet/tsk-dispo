import SwiftUI

struct AssignmentDetailView: View {
    let assignment: Assignment

    private var course: Course? { assignment.course }

    var body: some View {
        List {
            Section("Kurs") {
                LabeledContent("Titel", value: course?.title ?? "—")
                if let code = course?.courseType?.code {
                    LabeledContent("Typ", value: "\(code) – \(course?.courseType?.label ?? "")")
                }
                if let loc = course?.location, !loc.isEmpty {
                    LabeledContent("Ort", value: loc)
                }
            }

            Section("Termine") {
                if let dates = course?.allDates, !dates.isEmpty {
                    ForEach(dates, id: \.self) { date in
                        Text(date, format: .dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_CH")))
                    }
                } else {
                    Text("Keine Daten")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Zuteilung") {
                LabeledContent("Rolle") {
                    RoleBadge(role: assignment.role)
                }
                if let status = course?.status {
                    LabeledContent("Status") {
                        StatusChip(status: status)
                    }
                }
                LabeledContent("Bestätigt", value: assignment.confirmed ? "Ja" : "Nein")
            }

            if let info = course?.info, !info.isEmpty {
                Section("Info") {
                    Text(info)
                }
            }
        }
        .navigationTitle(course?.title ?? "Einsatz")
        .navigationBarTitleDisplayMode(.inline)
    }
}
