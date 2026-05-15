import SwiftUI
import AtollCore

struct ParticipantsTabView: View {
  let course: Course
  let user: CurrentUser
  let store: ParticipantsStore
  @State private var intakeStore = IntakeStore()
  @State private var selectedParticipant: CourseParticipant?

  var body: some View {
    Group {
      switch store.loadState {
      case .idle, .loading where store.participants.isEmpty:
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      case .error:
        ContentUnavailableView {
          Label("Fehler beim Laden", systemImage: "exclamationmark.triangle")
        } description: {
          Text(store.errorMessage ?? "")
        } actions: {
          Button("Nochmal versuchen") {
            Task { await store.load(courseId: course.id) }
          }
        }
      default:
        if store.participants.isEmpty {
          ContentUnavailableView(
            "Noch keine Teilnehmer",
            systemImage: "person.2",
            description: Text("Sobald Schüler eingeschrieben werden, erscheinen sie hier.")
          )
        } else {
          List(store.participants) { p in
            ParticipantRow(
              participant: p,
              intake: intakeStore.intakesByParticipant[p.id]
            )
            .contentShape(Rectangle())
            .onTapGesture { selectedParticipant = p }
          }
          .listStyle(.plain)
        }
      }
    }
    .refreshable {
      await store.load(courseId: course.id)
      await reloadIntakes()
    }
    .task { await reloadIntakes() }
    .sheet(item: $selectedParticipant) { participant in
      IntakeSheet(
        participant: participant,
        user: user,
        store: intakeStore,
        onSaved: { Task { await reloadIntakes() } }
      )
    }
  }

  private func reloadIntakes() async {
    let ids = store.participants.map(\.id)
    await intakeStore.load(participantIds: ids)
  }
}

private struct ParticipantRow: View {
  let participant: CourseParticipant
  let intake: IntakeChecklist?

  var body: some View {
    HStack(spacing: 12) {
      StudentAvatar(
        initials: participant.student?.initials ?? "—",
        id: participant.studentId,
        size: 36
      )
      VStack(alignment: .leading, spacing: 2) {
        Text(participant.student?.displayName ?? "—")
          .font(.subheadline.bold())
        HStack(spacing: 6) {
          if let level = participant.student?.level {
            Text(level)
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
          }
          Text(participant.status.label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusBackground.opacity(0.18), in: Capsule())
            .foregroundStyle(statusBackground)
          if !intakeComplete {
            Text("Intake offen")
              .font(.caption2)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.orange.opacity(0.18), in: Capsule())
              .foregroundStyle(.orange)
          }
        }
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption2.bold())
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 4)
  }

  private var intakeComplete: Bool {
    intake?.isComplete ?? false
  }

  private var statusBackground: Color {
    switch participant.status {
    case .enrolled:  .blue
    case .certified: .green
    case .dropped:   .secondary
    }
  }
}
