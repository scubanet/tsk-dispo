import SwiftUI

struct SkillCheckTabView: View {
  let course: Course

  var body: some View {
    ContentUnavailableView {
      Label("Skill-Check", systemImage: "checkmark.circle")
    } description: {
      Text("PADI-Skill-Matrix kommt in einer der nächsten Updates.")
    }
  }
}
