import SwiftUI

/// List of mutations that exhausted their retry budget (5 attempts) and were
/// marked dead by `MutationDrainer`. Each row offers two recoveries:
///   • Erneut versuchen — resets `attempts`/`isDead` and re-triggers the
///     drainer; useful when the failure was a transient server hiccup.
///   • Verwerfen        — drops the mutation entirely; the next refresh
///     from the server will overwrite the optimistic local state.
struct DeadLetterView: View {
  @Environment(CacheStore.self)      private var cache:   CacheStore?
  @Environment(MutationDrainer.self) private var drainer: MutationDrainer?

  var body: some View {
    Group {
      if let cache {
        let entries = cache.deadLetters()
        if entries.isEmpty {
          ContentUnavailableView(
            "Keine fehlgeschlagenen Aktionen",
            systemImage: "checkmark.circle"
          )
        } else {
          List(entries, id: \.id) { mutation in
            row(for: mutation, cache: cache)
          }
        }
      } else {
        ContentUnavailableView(
          "Cache nicht verfügbar",
          systemImage: "externaldrive.badge.xmark"
        )
      }
    }
    .navigationTitle("Fehlgeschlagene Aktionen")
  }

  @ViewBuilder
  private func row(for mutation: PendingLeadStatusMutation, cache: CacheStore) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Lead \(mutation.leadId.uuidString.prefix(8))")
        .font(.system(size: 13, weight: .semibold))
      Text("Versuchter Status: \(mutation.newStatus)")
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
      if let err = mutation.lastError {
        Text(err)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .lineLimit(3)
      }
      HStack {
        Button {
          Task { await drainer?.retryDeadLetter(mutationId: mutation.id) }
        } label: {
          Label("Erneut versuchen", systemImage: "arrow.clockwise")
        }
        .buttonStyle(.bordered)
        .disabled(drainer == nil)

        Button(role: .destructive) {
          cache.discardMutation(mutationId: mutation.id)
        } label: {
          Label("Verwerfen", systemImage: "trash")
        }
        .buttonStyle(.bordered)
      }
      .font(.system(size: 12))
    }
    .padding(.vertical, 4)
  }
}
