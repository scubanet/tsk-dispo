import SwiftUI

struct SkillCheckTabView: View {
  let course: Course
  let user: CurrentUser
  let participants: [CourseParticipant]

  @State private var store = SkillCheckStore()
  @State private var skillForDateEdit: SkillDefinition?

  var body: some View {
    Group {
      switch store.loadState {
      case .idle, .loading where store.recordsByKey.isEmpty && store.definitions.isEmpty:
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      case .error:
        ContentUnavailableView {
          Label("Fehler beim Laden", systemImage: "exclamationmark.triangle")
        } description: {
          Text(store.errorMessage ?? "")
        } actions: {
          Button("Nochmal versuchen") {
            Task { await reload() }
          }
        }
      default:
        if store.definitions.isEmpty {
          ContentUnavailableView(
            "Keine Skills hinterlegt",
            systemImage: "checkmark.circle",
            description: Text("Für diesen Kurs-Typ sind keine Skill-Definitionen vorhanden.")
          )
        } else if participants.isEmpty {
          ContentUnavailableView(
            "Keine Teilnehmer",
            systemImage: "person.2",
            description: Text("Sobald Schüler eingeschrieben sind, kannst du Skills abhaken.")
          )
        } else {
          skillsList
        }
      }
    }
    .refreshable { await reload() }
    .task { await reload() }
    .sheet(item: $skillForDateEdit) { skill in
      SkillDatePickerSheet(
        skill: skill,
        currentDate: store.dateForSkill(skill.skillCode),
        onSave: { newDate in
          Task {
            await store.updateDateForSkill(
              courseId: course.id,
              skillCode: skill.skillCode,
              newDate: newDate
            )
          }
        }
      )
    }
  }

  private var skillsList: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 18, pinnedViews: []) {
        ForEach(orderedSections, id: \.self) { section in
          if let skills = skillsBySection[section], !skills.isEmpty {
            sectionHeader(section)
            ForEach(skills) { skill in
              skillRow(skill)
            }
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
  }

  private func sectionHeader(_ section: String) -> some View {
    Text(SkillSection.labelsDe[section] ?? section.uppercased())
      .font(.caption.bold())
      .tracking(0.5)
      .foregroundStyle(.secondary)
      .padding(.top, 8)
  }

  private func skillRow(_ skill: SkillDefinition) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text(skill.label)
          .font(.subheadline.weight(.medium))
        Spacer()
        Button {
          skillForDateEdit = skill
        } label: {
          HStack(spacing: 4) {
            Text(Self.formatPillDate(store.dateForSkill(skill.skillCode)))
            Image(systemName: "chevron.down")
              .font(.system(size: 9, weight: .semibold))
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(
            Capsule()
              .fill(Color(.systemGray6))
          )
        }
        .buttonStyle(.plain)
      }
      LazyVGrid(columns: chipColumns, alignment: .leading, spacing: 6) {
        ForEach(participants) { p in
          SkillChip(
            initials: p.student?.initials ?? "—",
            participantId: p.id,
            isDone: store.isDone(participantId: p.id, skillCode: skill.skillCode),
            onTap: {
              Task {
                await store.toggle(
                  courseId: course.id,
                  participantId: p.id,
                  skillCode: skill.skillCode,
                  instructorId: user.instructorId
                )
              }
            }
          )
        }
      }
    }
    .padding(10)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(.systemBackground))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(.systemGray5), lineWidth: 0.5)
    )
  }

  private var chipColumns: [GridItem] {
    Array(repeating: GridItem(.flexible(minimum: 44, maximum: .infinity), spacing: 6), count: 4)
  }

  private var skillsBySection: [String: [SkillDefinition]] {
    Dictionary(grouping: store.definitions, by: \.section)
  }

  private var orderedSections: [String] {
    SkillSection.order.filter { skillsBySection[$0] != nil }
  }

  private func reload() async {
    if store.definitions.isEmpty {
      await store.loadDefinitions(courseTypeCode: "owd")
    }
    await store.loadRecords(courseId: course.id)
  }

  private static let pillDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "de_CH")
    f.dateFormat = "d. MMM"
    return f
  }()

  private static let isoDateParser: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Europe/Zurich")
    return f
  }()

  private static func formatPillDate(_ isoDate: String) -> String {
    guard let date = isoDateParser.date(from: isoDate) else { return isoDate }
    return pillDateFormatter.string(from: date)
  }
}
