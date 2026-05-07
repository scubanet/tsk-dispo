import SwiftUI
import SwiftData
import UIKit

// ═══════════════════════════════════════
// MARK: - Export Sheet (Phase 5)
// ═══════════════════════════════════════

/// Sheet for exporting dive data. Three formats:
///   • Full logbook PDF (all dives, optional date-range filter)
///   • Single dive PDF (if a specific dive is passed in)
///   • CSV (spreadsheet-friendly, all fields)
///
/// After rendering, the user gets a UIActivityViewController (share sheet)
/// so they can save to Files, email, AirDrop, send via Messages, etc.
struct ExportSheet: View {
    // When passed a dive, the sheet defaults to single-dive export.
    let singleDive: Dive?

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Dive.date, order: .reverse) private var allDives: [Dive]
    @Query private var profiles: [DiverProfile]

    @AppStorage("appLanguage") private var appLanguage = "en"

    enum Format: String, CaseIterable, Identifiable {
        case logbookPDF, singleDivePDF, csv
        var id: String { rawValue }
    }

    @State private var format: Format
    @State private var useDateRange: Bool = false
    @State private var fromDate: Date = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
    @State private var toDate: Date = .now
    @State private var shareItem: ShareItem?
    @State private var isExporting: Bool = false
    @State private var errorMessage: String?

    init(singleDive: Dive? = nil) {
        self.singleDive = singleDive
        _format = State(initialValue: singleDive == nil ? .logbookPDF : .singleDivePDF)
    }

    private var profile: DiverProfile? { profiles.first }
    private var isDE: Bool { appLanguage == "de" }

    // Dives filtered by date range if enabled
    private var filteredDives: [Dive] {
        guard useDateRange else { return allDives }
        return allDives.filter { $0.date >= fromDate && $0.date <= toDate }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.deepOcean.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        intro

                        formatSection

                        if format == .logbookPDF || format == .csv {
                            dateRangeSection
                        }

                        previewSection

                        if let msg = errorMessage {
                            Text(msg)
                                .font(.system(size: 12))
                                .foregroundColor(.coral)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.coral.opacity(0.1)))
                        }

                        exportButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isDE ? "Export" : "Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isDE ? "Schließen" : "Close") { dismiss() }
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .toolbarBackground(Color.deepOcean, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(item: $shareItem) { item in
                ActivityView(items: [item.url])
            }
        }
        .preferredColorScheme(.dark)
    }

    // ═══════════════════════════════════════
    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text((isDE ? "Logbuch exportieren" : "Export Logbook").uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.seafoam)
                .tracking(1.5)
            Text(isDE
                 ? "Wähle ein Format und teile per AirDrop, E-Mail oder speichere in Dateien."
                 : "Pick a format and share via AirDrop, email, or save to Files.")
                .font(.system(size: 13))
                .foregroundColor(.textDim)
        }
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(isDE ? "Format" : "Format")

            VStack(spacing: 8) {
                if singleDive != nil {
                    formatRow(
                        format: .singleDivePDF,
                        icon: "doc.richtext",
                        title: isDE ? "Einzel-TG PDF" : "Single Dive PDF",
                        subtitle: isDE ? "Eine A4-Seite mit allen Details" : "One A4 page, full detail"
                    )
                }
                formatRow(
                    format: .logbookPDF,
                    icon: "book.closed.fill",
                    title: isDE ? "Logbuch PDF" : "Logbook PDF",
                    subtitle: isDE ? "Cover + 2 TGs pro Seite + Zusammenfassung" : "Cover + 2 dives per page + summary"
                )
                formatRow(
                    format: .csv,
                    icon: "tablecells",
                    title: "CSV",
                    subtitle: isDE ? "Für Excel, Numbers, oder Migration" : "For Excel, Numbers, or migration"
                )
            }
        }
    }

    private func formatRow(format f: Format, icon: String, title: String, subtitle: String) -> some View {
        let selected = format == f
        return Button {
            format = f
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill((selected ? Color.seafoam : Color.white.opacity(0.08))).frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(selected ? .deepOcean : .seafoam)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.textDim)
                }
                Spacer()

                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(selected ? .seafoam : .white.opacity(0.25))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(selected ? Color.seafoam.opacity(0.08) : Color.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.seafoam.opacity(0.5) : Color.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $useDateRange) {
                Text(isDE ? "Zeitraum einschränken" : "Limit date range")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .tint(.seafoam)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cardBorder, lineWidth: 1))

            if useDateRange {
                HStack(spacing: 10) {
                    DatePicker(isDE ? "Von" : "From", selection: $fromDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardBg))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardBorder, lineWidth: 1))

                    DatePicker(isDE ? "Bis" : "To", selection: $toDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardBg))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardBorder, lineWidth: 1))
                }
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(isDE ? "Vorschau" : "Preview")

            HStack(spacing: 14) {
                Image(systemName: previewIcon)
                    .font(.system(size: 26))
                    .foregroundColor(.seafoam)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(previewFilename)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    Text(previewSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.textDim)
                }

                Spacer()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cardBorder, lineWidth: 1))
        }
    }

    private var exportButton: some View {
        Button {
            Task { await performExport() }
        } label: {
            HStack(spacing: 8) {
                if isExporting {
                    ProgressView().tint(.deepOcean)
                } else {
                    Image(systemName: "square.and.arrow.up.fill")
                }
                Text(isExporting
                     ? (isDE ? "Wird generiert..." : "Generating...")
                     : (isDE ? "Exportieren & Teilen" : "Export & Share"))
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.deepOcean)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(canExport ? Color.seafoam : Color.seafoam.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canExport || isExporting)
        .padding(.top, 8)
    }

    // ═══════════════════════════════════════
    // MARK: - Export Logic

    private var canExport: Bool {
        switch format {
        case .singleDivePDF:
            return singleDive != nil
        case .logbookPDF, .csv:
            return !filteredDives.isEmpty
        }
    }

    @MainActor
    private func performExport() async {
        errorMessage = nil
        isExporting = true
        defer { isExporting = false }

        do {
            let url: URL
            switch format {
            case .singleDivePDF:
                guard let dive = singleDive else {
                    errorMessage = isDE ? "Kein TG ausgewählt." : "No dive selected."
                    return
                }
                let data = PDFExporter.exportSingleDive(dive, profile: profile, languageCode: appLanguage)
                url = try writeToTemp(data: data, filename: singleDiveFilename(dive))

            case .logbookPDF:
                let data = PDFExporter.exportLogbook(filteredDives, profile: profile, languageCode: appLanguage)
                url = try writeToTemp(data: data, filename: logbookFilename())

            case .csv:
                let csv = CSVExporter.export(filteredDives, languageCode: appLanguage)
                guard let data = csv.data(using: .utf8) else {
                    errorMessage = isDE ? "CSV-Kodierung fehlgeschlagen." : "CSV encoding failed."
                    return
                }
                url = try writeToTemp(data: data, filename: csvFilename())
            }
            shareItem = ShareItem(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Write to the app's temporary directory so the share sheet can pass a
    /// proper file: URL to other apps (Mail, Files, AirDrop all want files
    /// on disk, not in-memory Data).
    private func writeToTemp(data: Data, filename: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(filename)
        // Remove any previous file with the same name — otherwise repeated
        // exports end up using stale content if we ever switched to append mode.
        try? FileManager.default.removeItem(at: url)
        try data.write(to: url, options: .atomic)
        return url
    }

    // ═══════════════════════════════════════
    // MARK: - Filenames

    private func singleDiveFilename(_ dive: Dive) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let safeSite = dive.siteName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        return "DiveLog_\(df.string(from: dive.date))_\(safeSite)_\(dive.number).pdf"
    }

    private func logbookFilename() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let name = (profile?.name ?? "AtollLog")
            .replacingOccurrences(of: " ", with: "_")
        return "AtollLog_\(name)_\(df.string(from: .now)).pdf"
    }

    private func csvFilename() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return "DiveLog_\(df.string(from: .now)).csv"
    }

    // ═══════════════════════════════════════
    // MARK: - Preview helpers

    private var previewIcon: String {
        switch format {
        case .singleDivePDF: return "doc.text.fill"
        case .logbookPDF:    return "book.fill"
        case .csv:           return "tablecells.fill"
        }
    }

    private var previewFilename: String {
        switch format {
        case .singleDivePDF:
            return singleDive.map(singleDiveFilename) ?? "DiveLog_–_.pdf"
        case .logbookPDF:
            return logbookFilename()
        case .csv:
            return csvFilename()
        }
    }

    private var previewSubtitle: String {
        switch format {
        case .singleDivePDF:
            return isDE ? "1 TG · 1 Seite" : "1 dive · 1 page"
        case .logbookPDF:
            let n = filteredDives.count
            let pages = 2 + Int(ceil(Double(n) / 2.0))  // cover + dive pages + summary
            return isDE ? "\(n) TGs · ~\(pages) Seiten" : "\(n) dives · ~\(pages) pages"
        case .csv:
            return isDE ? "\(filteredDives.count) Datensätze" : "\(filteredDives.count) rows"
        }
    }

    // ═══════════════════════════════════════

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.labelDim)
            .tracking(1.5)
    }
}

// ═══════════════════════════════════════
// MARK: - Share Item + Activity View
// ═══════════════════════════════════════

/// Thin Identifiable wrapper so `.sheet(item:)` works with a single URL.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// UIKit bridge for UIActivityViewController. SwiftUI's ShareLink exists but
/// UIActivityViewController gives finer control (e.g., excluded activity
/// types) and works reliably across iOS 17/18.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
