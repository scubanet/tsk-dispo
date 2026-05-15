import SwiftUI
import AtollCore

struct StudentsView: View {
  let user: CurrentUser

  @State private var store = StudentsStore()
  @State private var query: String = ""

  var body: some View {
    NavigationStack {
      Group {
        switch store.loadState {
        case .idle, .loading where store.allStudents.isEmpty:
          ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
          ContentUnavailableView {
            Label("Fehler beim Laden", systemImage: "exclamationmark.triangle")
          } description: {
            Text(store.errorMessage ?? "")
          } actions: {
            Button("Nochmal versuchen") {
              Task { await store.loadAll() }
            }
          }
        default:
          if store.allStudents.isEmpty {
            ContentUnavailableView(
              "Noch keine Schüler",
              systemImage: "person.2",
              description: Text("Sobald Schüler eingeschrieben sind, erscheinen sie hier.")
            )
          } else if filtered.isEmpty {
            ContentUnavailableView.search(text: query)
          } else {
            list
          }
        }
      }
      .navigationTitle("Studenten")
      .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name oder Email")
      .refreshable { await store.loadAll() }
      .task { await store.loadAll() }
    }
  }

  private var filtered: [Student] {
    store.search(query)
  }

  private var grouped: [(level: String, students: [Student])] {
    let groups = Dictionary(grouping: filtered, by: { $0.level ?? "Ohne Level" })
    let knownOrder = ["DSD", "Scuba Diver", "OWD", "AOWD", "Rescue", "Divemaster", "Instructor", "Other"]
    let sortedKeys = groups.keys.sorted { lhs, rhs in
      let li = knownOrder.firstIndex(of: lhs) ?? Int.max
      let ri = knownOrder.firstIndex(of: rhs) ?? Int.max
      if li != ri { return li < ri }
      if lhs == "Ohne Level" { return false }
      if rhs == "Ohne Level" { return true }
      return lhs < rhs
    }
    return sortedKeys.map { (level: $0, students: groups[$0] ?? []) }
  }

  private var list: some View {
    List {
      ForEach(grouped, id: \.level) { group in
        Section(group.level) {
          ForEach(group.students) { student in
            NavigationLink(value: student) {
              StudentRow(student: student)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationDestination(for: Student.self) { student in
      StudentDetailView(student: student)
    }
  }
}

private struct StudentRow: View {
  let student: Student

  var body: some View {
    HStack(spacing: 12) {
      StudentAvatar(
        initials: student.initials,
        id: student.id,
        size: 36
      )
      VStack(alignment: .leading, spacing: 2) {
        Text(student.displayName)
          .font(.subheadline.bold())
        if let email = student.primaryEmail {
          Text(email)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
    }
    .padding(.vertical, 4)
  }
}
