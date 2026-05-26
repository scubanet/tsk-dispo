import SwiftUI

/// Slim top-edge indicator shown when `ReachabilityMonitor.isConnected` is
/// false. Lives inside `.safeAreaInset(edge: .top)` so it pushes content
/// down without overlaying it.
struct OfflineBanner: View {
  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(.yellow)
        .frame(width: 6, height: 6)
      Text("Offline — Status-Änderungen werden synchronisiert sobald wieder verbunden")
        .font(.system(size: 11, weight: .medium))
        .lineLimit(2)
        .foregroundStyle(.secondary)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity)
    .background(.thinMaterial)
  }
}

#Preview {
  VStack(spacing: 0) {
    OfflineBanner()
    Spacer()
  }
}
