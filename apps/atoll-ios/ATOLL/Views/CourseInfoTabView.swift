import SwiftUI
import AtollCore

struct CourseInfoTabView: View {
  let course: Course

  var body: some View {
    List {
      Section("Kurs") {
        LabeledContent("Titel", value: course.title)
        if let code = course.courseType?.code {
          LabeledContent("Typ", value: "\(code) – \(course.courseType?.label ?? "")")
        }
        if let loc = course.location, !loc.isEmpty {
          LabeledContent("Ort", value: loc)
        }
        if let status = course.status {
          LabeledContent("Status", value: status.label)
        }
      }

      Section("Termine") {
        if course.allDates.isEmpty {
          Text("Keine Daten").foregroundStyle(.secondary)
        } else {
          ForEach(course.allDates, id: \.self) { date in
            Text(date, format: .dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_CH")))
          }
        }
      }

      if let info = course.info, !info.isEmpty {
        Section("Beschreibung") {
          Text(info)
        }
      }

      if let notes = course.notes, !notes.isEmpty {
        Section("Notizen") {
          Text(notes)
        }
      }
    }
  }
}
