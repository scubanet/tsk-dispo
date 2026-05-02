import SwiftUI

struct ProfileView: View {
  let user: CurrentUser
  @Environment(AuthState.self) private var auth

  var body: some View {
    NavigationStack {
      List {
        Section {
          HStack(spacing: 14) {
            AvatarView(initials: user.initials ?? String(user.firstName.prefix(2)), color: user.color)
              .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
              Text(user.name).font(.title3.bold())
              Text(user.padiLevel).foregroundStyle(.secondary)
              if let email = user.email {
                Text(email).font(.caption).foregroundStyle(.tertiary)
              }
            }
            Spacer()
          }
          .padding(.vertical, 8)
        }

        Section("Rolle") {
          LabeledContent("Rolle", value: user.role.rawValue.capitalized)
          LabeledContent("Tenant", value: Config.tenantName)
        }

        Section {
          Button(role: .destructive) {
            Task { await auth.signOut() }
          } label: {
            Label("Logout", systemImage: "arrow.right.square")
          }
        }
      }
      .navigationTitle("Profil")
    }
  }
}
