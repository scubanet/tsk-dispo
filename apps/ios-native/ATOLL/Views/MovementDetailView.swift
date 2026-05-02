import SwiftUI

struct MovementDetailView: View {
    let movement: Movement

    var body: some View {
        List {
            // Hero
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(movement.amountChf, format: .currency(code: "CHF"))
                        .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(movement.amountChf < 0 ? .red : .primary)
                    if let date = movement.dateAsDate {
                        Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year().locale(Locale(identifier: "de_CH")))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    KindChip(kind: movement.kind)
                }
                .listRowSeparator(.hidden)
            }

            if let description = movement.description, !description.isEmpty {
                Section("Beschreibung") {
                    Text(description)
                }
            }

            if let bd = movement.breakdownJson {
                Section("Berechnung") {
                    if let code = bd.courseTypeCode {
                        LabeledContent("Kurstyp", value: code)
                    }
                    if let role = bd.role {
                        LabeledContent("Rolle", value: role.capitalized)
                    }
                    if let level = bd.padiLevel {
                        LabeledContent("PADI-Level", value: level)
                    }
                    if let theory = bd.theoryH {
                        LabeledContent("Theorie", value: pointsString(theory))
                    }
                    if let pool = bd.poolH {
                        LabeledContent("Pool", value: pointsString(pool))
                    }
                    if let lake = bd.lakeH {
                        LabeledContent("See", value: pointsString(lake))
                    }
                    if let total = bd.totalH {
                        LabeledContent("Total Punkte", value: pointsString(total))
                    }
                    if let share = bd.share, share != 1.0 {
                        LabeledContent("Anteil", value: "\(Int((share * 100).rounded())) %")
                    }
                    if let rate = bd.hourlyRate {
                        LabeledContent("CHF / Punkt", value: rate.formatted(.currency(code: "CHF")))
                    }
                }
            }
        }
        .navigationTitle(movement.kind.label)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pointsString(_ n: Double) -> String {
        n.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", n)
            : String(format: "%.1f", n)
    }
}
