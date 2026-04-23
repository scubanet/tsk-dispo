import SwiftUI

/// SwiftUI splash shown briefly on app startup before handing off to
/// MainTabView (or OnboardingView on first launch). Pure brand moment.
struct LaunchScreenView: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            // Adaptive gradient — tints from the app accent
            LinearGradient(
                colors: [
                    Color.appAccent.opacity(0.18),
                    Color(uiColor: .systemBackground),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle radial glow top-center
            RadialGradient(
                colors: [
                    Color.appAccent.opacity(0.12),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.25),
                startRadius: 40,
                endRadius: 320
            )
            .ignoresSafeArea()

            // Caustic light streaks
            GeometryReader { geo in
                ZStack {
                    causticStreak(x: geo.size.width * 0.22, width: geo.size.width * 0.08, height: geo.size.height * 0.5)
                    causticStreak(x: geo.size.width * 0.55, width: geo.size.width * 0.06, height: geo.size.height * 0.45)
                    causticStreak(x: geo.size.width * 0.78, width: geo.size.width * 0.09, height: geo.size.height * 0.55)
                }
            }
            .opacity(0.4)
            .ignoresSafeArea()

            // Logo lockup
            VStack(spacing: 18) {
                Spacer()

                // Icon glyph
                diveIcon
                    .frame(width: 128, height: 128)
                    .opacity(appear ? 1 : 0)
                    .scaleEffect(appear ? 1 : 0.92)

                // Wordmark
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Text("DIVELOG")
                            .font(.system(size: 28, weight: .bold))
                            .tracking(2.5)
                            .foregroundStyle(.primary)
                        Text("PRO")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(Color.appEmphasis)
                            .padding(.top, 2)
                    }
                    Text(L10n.currentLanguage == "de" ? "DEIN TAUCHLOGBUCH" : "YOUR DIVE LOG")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(Color.appAccent.opacity(0.7))
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 6)

                Spacer()
                Spacer()

                // Footer signature
                Text("PADI CD #335680")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .tracking(1.2)
                    .padding(.bottom, 40)
                    .opacity(appear ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                appear = true
            }
        }
    }

    // ═══════════════════════════════════════

    private var diveIcon: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let lensH = w * 0.55
            let lensW = w * 0.42
            let gap: CGFloat = 2
            ZStack {
                RoundedRectangle(cornerRadius: lensW * 0.32)
                    .stroke(Color.appAccent, lineWidth: w * 0.06)
                    .frame(width: lensW, height: lensH)
                    .offset(x: -(lensW + gap) / 2)
                RoundedRectangle(cornerRadius: lensW * 0.32)
                    .stroke(Color.appAccent, lineWidth: w * 0.06)
                    .frame(width: lensW, height: lensH)
                    .offset(x: (lensW + gap) / 2)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.appAccent)
                    .frame(width: gap + 6, height: lensH * 0.35)
                Circle()
                    .fill(Color.appEmphasis)
                    .frame(width: w * 0.04, height: w * 0.04)
            }
            .frame(width: w, height: geo.size.height)
        }
    }

    private func causticStreak(x: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: x - width * 0.3, y: 0))
            path.addLine(to: CGPoint(x: x + width * 0.3, y: 0))
            path.addLine(to: CGPoint(x: x + width * 1.2, y: height))
            path.addLine(to: CGPoint(x: x - width * 0.2, y: height))
            path.closeSubpath()
        }
        .fill(
            LinearGradient(colors: [
                Color.appAccent.opacity(0.15),
                Color.appAccent.opacity(0.0),
            ], startPoint: .top, endPoint: .bottom)
        )
        .blur(radius: 20)
    }
}

#Preview {
    LaunchScreenView()
}
