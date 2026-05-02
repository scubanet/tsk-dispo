import SwiftUI

struct ProfileView: View {
    let user: CurrentUser
    @Environment(AuthState.self) private var auth
    @State private var skillsStore = SkillsStore()

    var body: some View {
        NavigationStack {
            List {
                // Header
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

                // Skills
                Section("Skills (\(skillsStore.skills.count))") {
                    if !skillsStore.loaded {
                        HStack {
                            ProgressView()
                            Text("Lade Skills…")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                    } else if skillsStore.skills.isEmpty {
                        Text("Keine Skills hinterlegt — frag den Course Director, dass er sie eintragen kann.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        ForEach(skillsStore.grouped, id: \.category) { group in
                            DisclosureGroup {
                                ForEach(group.items) { skill in
                                    HStack {
                                        Text(skill.label)
                                            .font(.callout)
                                        Spacer()
                                        Text(skill.code)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(group.category)
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text("\(group.items.count)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                // Rolle / Kunde
                Section("Konto") {
                    LabeledContent("Rolle", value: user.role.rawValue.capitalized)
                    LabeledContent("Tenant", value: Config.tenantName)
                }

                // Logout
                Section {
                    Button(role: .destructive) {
                        Task { await auth.signOut() }
                    } label: {
                        Label("Logout", systemImage: "arrow.right.square")
                    }
                }
            }
            .navigationTitle("Profil")
            .refreshable { await skillsStore.load(instructorId: user.id) }
            .task { await skillsStore.load(instructorId: user.id) }
        }
    }
}
