import SwiftUI

/// Top-Bar mit ATOLL Branding links + Tenant-Indicator rechts.
/// Wird in den Hauptscreens oben über den NavigationStack-Inhalt gerendert.
struct BrandHeader: View {
  var body: some View {
    HStack {
      HStack(spacing: 8) {
        AtollLogo(size: 22)
        Text(Config.appName)
          .font(.caption.bold())
          .tracking(2)
      }

      Spacer()

      HStack(spacing: 6) {
        Circle()
          .fill(.green)
          .frame(width: 6, height: 6)
        Text(Config.tenantName)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal)
    .padding(.top, 4)
    .padding(.bottom, 8)
  }
}
