import SwiftUI

/// Tiny orange pill that shows the count of queued offline mutations. Used
/// as an overlay on the FAB avatar so the user always sees at a glance how
/// many writes are waiting for the drainer to push.
///
/// Renders nothing when `count == 0` so the avatar reads clean in the happy
/// path.
struct PendingBadge: View {
  let count: Int

  var body: some View {
    if count > 0 {
      Text("\(count)")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(Color.orange, in: Capsule())
    }
  }
}

#Preview {
  HStack(spacing: 20) {
    PendingBadge(count: 0)
    PendingBadge(count: 1)
    PendingBadge(count: 12)
  }
  .padding()
}
