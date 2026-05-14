import SwiftUI

struct CourseDetailView: View {
  let course: Course
  let user: CurrentUser

  enum Tab: String, CaseIterable, Identifiable {
    case participants, skillCheck, info
    var id: Self { self }
    var label: String {
      switch self {
      case .participants: "Teilnehmer"
      case .skillCheck:   "Skill-Check"
      case .info:         "Info"
      }
    }
  }

  @State private var selectedTab: Tab = .participants

  var body: some View {
    VStack(spacing: 0) {
      Picker("Bereich", selection: $selectedTab) {
        ForEach(Tab.allCases) { tab in
          Text(tab.label).tag(tab)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)
      .padding(.top, 8)

      Divider().padding(.top, 8)

      switch selectedTab {
      case .participants:
        ParticipantsTabView(course: course, user: user)
      case .skillCheck:
        SkillCheckTabView(course: course)
      case .info:
        CourseInfoTabView(course: course)
      }
    }
    .navigationTitle(course.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}
