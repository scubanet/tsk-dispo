import SwiftUI

/// Shared row style used by SettingsSection, DataManagementCard, and AccountCard.
/// Each row shows a leading SF Symbol icon, a label, and an optional trailing view.
func settingsRow<Content: View>(
    icon: String,
    label: String,
    @ViewBuilder trailing: () -> Content
) -> some View {
    HStack(spacing: DSSpacing.m + 2) {
        Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundStyle(Color.appAccent)
            .frame(width: 32)

        Text(label)
            .font(.system(size: 15))
            .foregroundStyle(.primary)

        Spacer()

        trailing()
    }
    .padding(DSSpacing.m + 2)
    .solidCard(cornerRadius: DSRadius.m)
}
