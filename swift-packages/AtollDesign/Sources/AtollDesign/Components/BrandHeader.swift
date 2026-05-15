import SwiftUI

/// Top-Bar mit ATOLL Branding links + Tenant-Indicator rechts.
/// Wird in den Hauptscreens oben über den NavigationStack-Inhalt gerendert.
///
/// `appName` und `tenantName` werden als Parameter übergeben, damit
/// BrandHeader app-unabhängig in der ganzen ATOLL-Suite nutzbar ist.
public struct BrandHeader: View {
  public let appName: String
  public let tenantName: String

  public init(appName: String, tenantName: String) {
    self.appName = appName
    self.tenantName = tenantName
  }

  public var body: some View {
    HStack {
      HStack(spacing: 8) {
        AtollLogo(size: 22)
        Text(appName)
          .font(.caption.bold())
          .tracking(2)
      }

      Spacer()

      HStack(spacing: 6) {
        Circle()
          .fill(.green)
          .frame(width: 6, height: 6)
        Text(tenantName)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal)
    .padding(.top, 4)
    .padding(.bottom, 8)
  }
}
