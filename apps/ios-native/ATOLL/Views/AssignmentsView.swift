import SwiftUI

struct AssignmentsView: View {
  let user: CurrentUser
  @State private var store = AssignmentsStore()

  var body: some View {
    NavigationStack {
      Group {
        switch store.loadState {
        case .loading where store.assignments.isEmpty, .idle:
          ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
          ContentUnavailableView {
            Label("Fehler beim Laden", systemImage: "exclamationmark.triangle")
          } description: {
            Text(store.errorMessage ?? "")
          } actions: {
            Button("Nochmal versuchen") {
              Task { await store.load(instructorId: user.id) }
            }
          }
        default:
          if store.assignments.isEmpty {
            ContentUnavailableView(
              "Noch keine Einsätze",
              systemImage: "calendar",
              description: Text("Sobald dir ein Kurs zugewiesen wird, erscheint er hier.")
            )
          } else {
            list
          }
        }
      }
      .navigationTitle("Meine Einsätze")
      .refreshable { await store.load(instructorId: user.id) }
      .task { await store.load(instructorId: user.id) }
      .navigationDestination(for: Assignment.self) { AssignmentDetailView(assignment: $0) }
    }
  }

  private var list: some View {
    List {
      ForEach(store.groupedByMonth(), id: \.monthLabel) { group in
        Section(group.monthLabel) {
          ForEach(group.items) { a in
            NavigationLink(value: a) {
              AssignmentRow(assignment: a)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
  }
}

struct AssignmentRow: View {
  let assignment: Assignment

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(dayString)
          .font(.title3.bold().monospacedDigit())
        Text(monthString.uppercased())
          .font(.caption2.bold())
          .tracking(1)
          .foregroundStyle(.secondary)
      }
      .frame(width: 44, alignment: .leading)

      VStack(alignment: .leading, spacing: 4) {
        Text(assignment.course?.title ?? "—")
          .font(.subheadline.bold())
          .lineLimit(2)
        HStack(spacing: 6) {
          if let code = assignment.course?.courseType?.code {
            Text(code)
              .font(.caption2.monospaced())
              .foregroundStyle(.tertiary)
          }
          RoleBadge(role: assignment.role)
          if let status = assignment.course?.status {
            StatusChip(status: status)
          }
        }
      }

      Spacer()
    }
    .padding(.vertical, 4)
  }

  private var dayString: String {
    guard let d = assignment.course?.startDateAsDate else { return "–" }
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_CH")
    f.dateFormat = "d"
    return f.string(from: d)
  }

  private var monthString: String {
    guard let d = assignment.course?.startDateAsDate else { return "" }
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_CH")
    f.dateFormat = "MMM"
    return f.string(from: d)
  }
}
