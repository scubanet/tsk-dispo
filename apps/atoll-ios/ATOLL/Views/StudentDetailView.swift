import SwiftUI

struct StudentDetailView: View {
  let student: Student

  var body: some View {
    List {
      Section {
        HStack(spacing: 16) {
          StudentAvatar(
            initials: student.initials,
            id: student.id,
            size: 64
          )
          VStack(alignment: .leading, spacing: 4) {
            Text(student.displayName)
              .font(.title3.bold())
            if let level = student.level {
              Text(level)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding(.vertical, 4)
      }

      Section("Kontakt") {
        if let email = student.primaryEmail, !email.isEmpty {
          LabeledContent("Email") {
            Text(email).textSelection(.enabled)
          }
        } else {
          Text("Keine Kontaktdaten").foregroundStyle(.secondary)
        }
      }

      Section {
        Text("Kursteilnahmen kommen in einer der nächsten Updates.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } header: {
        Text("Kursteilnahmen")
      }
    }
    .navigationTitle(student.displayName)
    .navigationBarTitleDisplayMode(.inline)
  }
}
