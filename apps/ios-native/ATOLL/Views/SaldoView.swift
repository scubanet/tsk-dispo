import SwiftUI

struct SaldoView: View {
    let user: CurrentUser
    @State private var store = MovementsStore()

    var body: some View {
        NavigationStack {
            Group {
                switch store.loadState {
                case .loading where store.movements.isEmpty, .idle:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                case .error:
                    ContentUnavailableView {
                        Label("Fehler beim Laden", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(store.errorMessage ?? "")
                    } actions: {
                        Button("Nochmal versuchen") {
                            Task { await store.load(instructorId: user.id) }
                        }
                    }
                default:
                    if store.visible.isEmpty {
                        ContentUnavailableView(
                            "Noch keine Bewegungen",
                            systemImage: "creditcard",
                            description: Text("Sobald du an einem abgeschlossenen Kurs warst, erscheinen Vergütungen hier.")
                        )
                    } else {
                        list
                    }
                }
            }
            .navigationTitle("Saldo")
            .refreshable { await store.load(instructorId: user.id) }
            .task { await store.load(instructorId: user.id) }
            .navigationDestination(for: Movement.self) { MovementDetailView(movement: $0) }
        }
    }

    // MARK: – List

    private var list: some View {
        List {
            Section {
                BalanceCard(balance: store.balance, count: store.visible.count, summary: summary)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            Section("Bewegungen") {
                ForEach(store.visible) { m in
                    NavigationLink(value: m) {
                        MovementRow(movement: m)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        ShareLink(
                            item: shareText(for: m),
                            preview: SharePreview(
                                m.description ?? m.kind.label,
                                image: Image(systemName: "creditcard.fill")
                            )
                        ) {
                            Label("Teilen", systemImage: "square.and.arrow.up")
                        }
                        .tint(.accentColor)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: – Summary

    private func shareText(for m: Movement) -> String {
        let amount = m.amountChf.formatted(.currency(code: "CHF"))
        let date = m.dateAsDate.map {
            $0.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "de_CH")))
        } ?? m.date
        let desc = m.description ?? m.kind.label
        return "\(amount) — \(desc) (\(date)) · ATOLL"
    }

    private var summary: BalanceSummary {
        let visible = store.visible
        return BalanceSummary(
            opening:    visible.filter { $0.kind == .opening    }.map(\.amountChf).reduce(0, +),
            payments:   visible.filter { $0.kind == .payment    }.map(\.amountChf).reduce(0, +),
            corrections: visible.filter { $0.kind == .correction }.map(\.amountChf).reduce(0, +)
        )
    }
}

// MARK: – Balance Card (top hero)

struct BalanceSummary {
    let opening: Double
    let payments: Double
    let corrections: Double
}

struct BalanceCard: View {
    let balance: Double
    let count: Int
    let summary: BalanceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aktueller Saldo")
                .font(.caption.bold())
                .tracking(1)
                .foregroundStyle(.white.opacity(0.85))

            Text(balance, format: .currency(code: "CHF").precision(.fractionLength(2)))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 18) {
                stat(label: "Eröffnung", value: summary.opening)
                Rectangle().frame(width: 0.5, height: 28).foregroundStyle(.white.opacity(0.3))
                stat(label: "Vergütungen", value: summary.payments)
                if summary.corrections != 0 {
                    Rectangle().frame(width: 0.5, height: 28).foregroundStyle(.white.opacity(0.3))
                    stat(label: "Korrekturen", value: summary.corrections)
                }
            }
            .foregroundStyle(.white)

            Text("\(count) Bewegungen")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.52, blue: 1.0), Color(red: 0.19, green: 0.69, blue: 0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func stat(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .currency(code: "CHF").precision(.fractionLength(0)))
                .font(.system(.body, design: .rounded).weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

// MARK: – Movement Row

struct MovementRow: View {
    let movement: Movement

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(movement.description ?? movement.kind.label)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let date = movement.dateAsDate {
                        Text(date, format: .dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "de_CH")))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    KindChip(kind: movement.kind)
                }
            }

            Spacer()

            Text(movement.amountChf, format: .currency(code: "CHF"))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(movement.amountChf < 0 ? .red : .primary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: – Kind Chip

struct KindChip: View {
    let kind: MovementKind

    var body: some View {
        Text(kind.label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch kind {
        case .payment:    .accentColor
        case .opening:    .gray
        case .correction: .orange
        }
    }
}
