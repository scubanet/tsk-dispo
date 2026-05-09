import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = StoreManager.shared
    @State private var isPurchasing = false

    @AppStorage("appLanguage") private var appLanguage: String = "en"
    private var isDE: Bool { appLanguage == "de" }

    var body: some View {
        NavigationStack {
            ZStack {
                HeroBackground()

                ScrollView {
                    VStack(spacing: DSSpacing.xl) {
                        headerSection
                        featuresSection
                        purchaseSection
                    }
                    .padding(.horizontal, DSSpacing.xl)
                    .padding(.top, DSSpacing.l)
                    .padding(.bottom, DSSpacing.xxxl)
                }
            }
            .navigationTitle(isDE ? "Instructor Pro" : "Instructor Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: DSSpacing.m) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.appAccent)
                .padding(.top, DSSpacing.xl)

            Text(isDE
                 ? "Werde zum digitalen Instructor"
                 : "Go digital with your teaching")
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text(isDE
                 ? "Verwalte Schüler, tracke Skills und dokumentiere Kurse — alles in einer App."
                 : "Manage students, track skills, and document courses — all in one app.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.m) {
            featureRow(
                icon: "person.2.fill",
                title: isDE ? "Schülerverwaltung" : "Student Management",
                subtitle: isDE
                    ? "Erstelle und verwalte Schülerprofile über mehrere Kurse hinweg"
                    : "Create and manage student profiles across multiple courses"
            )
            featureRow(
                icon: "checklist",
                title: isDE ? "Skill Assessment" : "Skill Assessment",
                subtitle: isDE
                    ? "PADI-konforme Skill-Bewertung für OWD, AOWD, Rescue & mehr"
                    : "PADI-compliant skill tracking for OWD, AOWD, Rescue & more"
            )
            featureRow(
                icon: "water.waves",
                title: isDE ? "Pool Sessions" : "Pool Sessions",
                subtitle: isDE
                    ? "Dokumentiere Confined-Water-Sessions mit Skill-Checklisten"
                    : "Document confined water sessions with skill checklists"
            )
            featureRow(
                icon: "graduationcap",
                title: isDE ? "Kurs-Tauchgänge" : "Course Dives",
                subtitle: isDE
                    ? "Weise Tauchgänge Kursen zu und tracke den Fortschritt"
                    : "Assign dives to courses and track student progress"
            )
        }
        .padding(DSSpacing.l)
        .glassCard(cornerRadius: DSRadius.xl)
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: DSSpacing.m) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.appAccent)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Purchase

    private var purchaseSection: some View {
        VStack(spacing: DSSpacing.m) {
            if let product = store.instructorProduct {
                Button {
                    guard !isPurchasing else { return }
                    isPurchasing = true
                    Task {
                        await store.buyInstructorPro()
                        isPurchasing = false
                        if store.isPro { dismiss() }
                    }
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(isDE ? "Freischalten für" : "Unlock for")
                            Text(product.displayPrice)
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.appAccent)
                    .foregroundStyle(.white)
                    .font(.system(size: 17, weight: .semibold))
                    .clipShape(RoundedRectangle(cornerRadius: DSRadius.l))
                }
                .disabled(isPurchasing)
            } else {
                ProgressView()
                    .padding()
            }

            Button {
                Task { await store.restore() }
            } label: {
                Text(isDE ? "Käufe wiederherstellen" : "Restore purchases")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            if let err = store.purchaseError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Text(isDE ? "Einmaliger Kauf — kein Abo." : "One-time purchase — no subscription.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    PaywallView()
}
