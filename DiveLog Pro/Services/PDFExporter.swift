import UIKit
import PDFKit
import SwiftUI

// ═══════════════════════════════════════
// MARK: - PDF Exporter (Phase 5)
// ═══════════════════════════════════════

/// Renders AtollLog content to PDF. Two layouts:
///   • Single dive → one A4 portrait page with all detail (header, stats grid,
///     conditions, equipment, notes, marine life, signatures).
///   • Full logbook → A4 portrait with two dives per page, PADI-style strip
///     layout (cover sheet + dive pages + summary).
///
/// All drawing uses UIKit directly via UIGraphicsPDFRenderer — no SwiftUI
/// rendering because we need precise typography + page-break control.
enum PDFExporter {

    // A4 in points (72 dpi). 595 × 842.
    static let pageSize = CGSize(width: 595, height: 842)
    static let margin: CGFloat = 40

    // Brand colors as UIColor (mirroring Theme.swift).
    static let deepOcean  = UIColor(red: 0.043, green: 0.114, blue: 0.180, alpha: 1) // #0B1D2E
    static let oceanBlue  = UIColor(red: 0.000, green: 0.467, blue: 0.714, alpha: 1) // #0077B6
    static let seafoam    = UIColor(red: 0.565, green: 0.878, blue: 0.784, alpha: 1) // #90E0C8
    static let coral      = UIColor(red: 0.910, green: 0.447, blue: 0.353, alpha: 1) // #E8725A
    static let sandLight  = UIColor(red: 0.961, green: 0.941, blue: 0.910, alpha: 1) // #F5F0E8
    static let ink        = UIColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)
    static let inkSoft    = UIColor(red: 0.35, green: 0.38, blue: 0.44, alpha: 1)
    static let rule       = UIColor(red: 0.85, green: 0.87, blue: 0.90, alpha: 1)

    // ═══════════════════════════════════════
    // MARK: - Public API

    /// Render a single dive to a full-page A4 PDF. Returns the PDF bytes.
    static func exportSingleDive(_ dive: Dive, profile: DiverProfile?, languageCode: String) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize),
                                             format: pdfFormat(title: "AtollLog #\(dive.number)",
                                                               author: profile?.name ?? "AtollLog"))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            drawSingleDivePage(dive: dive, profile: profile, lang: languageCode)
        }
    }

    /// Render a multi-dive logbook. Layout: cover page, then 2 dives per page
    /// in a PADI-inspired strip format, then a summary page at the end.
    static func exportLogbook(_ dives: [Dive], profile: DiverProfile?, languageCode: String) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize),
                                             format: pdfFormat(title: "AtollLog — \(profile?.name ?? "Logbook")",
                                                               author: profile?.name ?? "AtollLog"))
        return renderer.pdfData { ctx in
            // Cover
            ctx.beginPage()
            drawCover(dives: dives, profile: profile, lang: languageCode)

            // Chunk dives 2-per-page (newest first — logbook-reader convention)
            let sorted = dives.sorted { $0.date > $1.date }
            for pairStart in stride(from: 0, to: sorted.count, by: 2) {
                ctx.beginPage()
                let top = sorted[pairStart]
                let bottom = pairStart + 1 < sorted.count ? sorted[pairStart + 1] : nil
                drawLogbookPage(top: top, bottom: bottom, profile: profile, lang: languageCode,
                                pageNumber: pairStart / 2 + 1)
            }

            // Summary
            ctx.beginPage()
            drawSummary(dives: sorted, profile: profile, lang: languageCode)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Single Dive Page

    private static func drawSingleDivePage(dive: Dive, profile: DiverProfile?, lang: String) {
        var y: CGFloat = margin

        // Header band
        y = drawHeaderBand(dive: dive, lang: lang, y: y)
        y += 18

        // Location block
        y = drawSectionTitle(loc("Tauchplatz", "Dive Site", lang), y: y)
        y = drawKeyValueGrid(items: [
            (loc("Name", "Name", lang), dive.siteName.isEmpty ? "—" : dive.siteName),
            (loc("Ort", "Location", lang), dive.siteLocation.isEmpty ? "—" : dive.siteLocation),
            (loc("Tauchbasis", "Dive Center", lang), dive.diveCenterName.isEmpty ? "—" : dive.diveCenterName),
            (loc("Einstieg", "Entry", lang), dive.entryType.capitalized),
        ], columns: 2, y: y)
        y += 14

        // Stats grid
        y = drawSectionTitle(loc("Tauchgang", "Dive", lang), y: y)
        y = drawKeyValueGrid(items: [
            (loc("Max. Tiefe", "Max Depth", lang), String(format: "%.1f m", dive.maxDepth)),
            (loc("Ø Tiefe", "Avg Depth", lang), String(format: "%.1f m", dive.avgDepth)),
            (loc("Grundzeit", "Bottom Time", lang), "\(dive.bottomTime) min"),
            (loc("Tauchzeit", "Total Time", lang), "\(dive.totalTime) min"),
            (loc("Safety Stop", "Safety Stop", lang), "\(dive.safetyStopMin) min"),
            (loc("Ø SAC", "Avg SAC", lang), String(format: "%.1f l/min", dive.sacRate)),
        ], columns: 3, y: y)
        y += 14

        // Conditions
        y = drawSectionTitle(loc("Bedingungen", "Conditions", lang), y: y)
        y = drawKeyValueGrid(items: [
            (loc("Wetter", "Weather", lang), dive.weather.replacingOccurrences(of: "_", with: " ").capitalized),
            (loc("Lufttemp.", "Air Temp", lang), String(format: "%.0f°C", dive.airTemp)),
            (loc("Wasser Oberfl.", "Surface Temp", lang), String(format: "%.0f°C", dive.waterTempSurface)),
            (loc("Wasser Tiefe", "Bottom Temp", lang), String(format: "%.0f°C", dive.waterTempBottom)),
            (loc("Sicht", "Visibility", lang), "\(dive.visibility) m"),
            (loc("Strömung", "Current", lang), dive.current.capitalized),
            (loc("Wellen", "Waves", lang), dive.waves.capitalized),
            (loc("Wasser", "Water", lang), dive.waterType.capitalized),
        ], columns: 4, y: y)
        y += 14

        // Equipment
        y = drawSectionTitle(loc("Ausrüstung", "Equipment", lang), y: y)
        y = drawKeyValueGrid(items: [
            (loc("Anzug", "Suit", lang), formatSuit(dive.suit)),
            (loc("Blei", "Weight", lang), String(format: "%.1f kg", dive.weightKg)),
            (loc("Flasche", "Cylinder", lang), "\(dive.cylinderType.capitalized) \(Int(dive.cylinderSizeLiters))L"),
            (loc("Gas", "Gas", lang), dive.gas.uppercased()),
            (loc("Start", "Start", lang), "\(dive.tankStartBar) bar"),
            (loc("Ende", "End", lang), "\(dive.tankEndBar) bar"),
            (loc("Verbraucht", "Used", lang), "\(dive.tankUsed) bar"),
            (loc("bar/min", "bar/min", lang), String(format: "%.1f", dive.barPerMinute)),
        ], columns: 4, y: y)
        y += 14

        // Marine life
        if !dive.marineLife.isEmpty {
            y = drawSectionTitle(loc("Marine Life", "Unterwasserwelt", lang), y: y)
            y = drawTagWrap(dive.marineLife, y: y)
            y += 10
        }

        // Buddies
        if !dive.buddyNames.isEmpty {
            y = drawSectionTitle(loc("Buddies", "Buddies", lang), y: y)
            y = drawParagraph(dive.buddyNames, y: y, size: 11)
            y += 10
        }

        // Notes
        if !dive.notes.isEmpty {
            y = drawSectionTitle(loc("Notizen", "Notes", lang), y: y)
            y = drawParagraph(dive.notes, y: y, size: 10)
            y += 10
        }

        // Signatures (if space allows — else they may be cut. That's fine
        // for a one-pager; the logbook variant handles pagination properly.)
        let sigList = dive.signatures ?? []
        if !sigList.isEmpty, y < pageSize.height - 160 {
            y = drawSectionTitle(loc("Unterschriften", "Signatures", lang), y: y)
            for sig in sigList.prefix(2) {
                guard y < pageSize.height - 100 else { break }
                y = drawSignatureBlock(sig, y: y)
                y += 8
            }
        }

        // Footer
        drawFooter(pageNumber: 1, totalPages: 1, profile: profile, lang: lang)
    }

    // ═══════════════════════════════════════
    // MARK: - Header Band (single dive)

    private static func drawHeaderBand(dive: Dive, lang: String, y: CGFloat) -> CGFloat {
        let bandH: CGFloat = 72
        let rect = CGRect(x: margin, y: y, width: pageSize.width - 2 * margin, height: bandH)

        // Dark rounded band
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        deepOcean.setFill()
        path.fill()

        // Left accent bar (coral)
        coral.setFill()
        UIBezierPath(roundedRect: CGRect(x: rect.minX, y: rect.minY + 8,
                                          width: 4, height: bandH - 16),
                     cornerRadius: 2).fill()

        // #NNN badge
        let badge = "#\(dive.number)"
        drawText(badge, at: CGPoint(x: rect.minX + 18, y: rect.minY + 12),
                 size: 22, weight: .bold, color: seafoam, design: .monospaced)

        // Site name
        drawText(dive.siteName.isEmpty ? loc("Unbenannter TG", "Unnamed Dive", lang) : dive.siteName,
                 at: CGPoint(x: rect.minX + 90, y: rect.minY + 12),
                 size: 18, weight: .bold, color: .white)

        // Location
        drawText(dive.siteLocation,
                 at: CGPoint(x: rect.minX + 90, y: rect.minY + 36),
                 size: 11, weight: .regular, color: UIColor.white.withAlphaComponent(0.7))

        // Right: date + time
        let dateStr = dive.date.formatted(date: .long, time: .omitted)
        let timeStr = dive.date.formatted(date: .omitted, time: .shortened)
        let dateSize = textSize(dateStr, size: 12, weight: .semibold)
        drawText(dateStr,
                 at: CGPoint(x: rect.maxX - 14 - dateSize.width, y: rect.minY + 14),
                 size: 12, weight: .semibold, color: .white)
        let timeSize = textSize(timeStr, size: 11, weight: .regular)
        drawText(timeStr,
                 at: CGPoint(x: rect.maxX - 14 - timeSize.width, y: rect.minY + 32),
                 size: 11, weight: .regular, color: UIColor.white.withAlphaComponent(0.7))

        // Bottom: dive type chip
        let typeChip = dive.diveType.uppercased()
        let chipSize = textSize(typeChip, size: 9, weight: .bold)
        let chipRect = CGRect(x: rect.maxX - 16 - chipSize.width - 16,
                              y: rect.maxY - 24, width: chipSize.width + 16, height: 18)
        let chipPath = UIBezierPath(roundedRect: chipRect, cornerRadius: 9)
        seafoam.withAlphaComponent(0.2).setFill()
        chipPath.fill()
        seafoam.setStroke()
        chipPath.lineWidth = 0.8
        chipPath.stroke()
        drawText(typeChip,
                 at: CGPoint(x: chipRect.minX + 8, y: chipRect.minY + 4),
                 size: 9, weight: .bold, color: seafoam, tracking: 1.2)

        return y + bandH
    }

    // ═══════════════════════════════════════
    // MARK: - Logbook Page (2 dives / page)

    private static func drawLogbookPage(top: Dive, bottom: Dive?, profile: DiverProfile?, lang: String, pageNumber: Int) {
        drawPageHeader(profile: profile, lang: lang)

        let usable = pageSize.height - margin - 60 // minus footer
        let top0: CGFloat = margin + 36
        let slotH = (usable - top0) / 2

        drawLogbookSlot(dive: top, origin: CGPoint(x: margin, y: top0),
                        size: CGSize(width: pageSize.width - 2 * margin, height: slotH - 12), lang: lang)

        if let bottom = bottom {
            drawLogbookSlot(dive: bottom, origin: CGPoint(x: margin, y: top0 + slotH),
                            size: CGSize(width: pageSize.width - 2 * margin, height: slotH - 12), lang: lang)
        }

        drawFooter(pageNumber: pageNumber, totalPages: nil, profile: profile, lang: lang)
    }

    private static func drawLogbookSlot(dive: Dive, origin: CGPoint, size: CGSize, lang: String) {
        let rect = CGRect(origin: origin, size: size)

        // Outer card
        rule.setStroke()
        let card = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        card.lineWidth = 0.7
        card.stroke()

        // Top strip (deep ocean)
        let stripH: CGFloat = 28
        let stripRect = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: stripH)
        let stripPath = UIBezierPath()
        stripPath.move(to: CGPoint(x: rect.minX + 8, y: rect.minY))
        stripPath.addLine(to: CGPoint(x: rect.maxX - 8, y: rect.minY))
        stripPath.addArc(withCenter: CGPoint(x: rect.maxX - 8, y: rect.minY + 8),
                         radius: 8, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        stripPath.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + stripH))
        stripPath.addLine(to: CGPoint(x: rect.minX, y: rect.minY + stripH))
        stripPath.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 8))
        stripPath.addArc(withCenter: CGPoint(x: rect.minX + 8, y: rect.minY + 8),
                         radius: 8, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        stripPath.close()
        deepOcean.setFill()
        stripPath.fill()

        // Strip content: #N — siteName — date
        drawText("#\(dive.number)", at: CGPoint(x: stripRect.minX + 12, y: stripRect.minY + 8),
                 size: 11, weight: .bold, color: seafoam, design: .monospaced)
        let titleX: CGFloat = stripRect.minX + 48
        drawText(dive.siteName.isEmpty ? loc("Unbenannt", "Unnamed", lang) : dive.siteName,
                 at: CGPoint(x: titleX, y: stripRect.minY + 8),
                 size: 12, weight: .bold, color: .white)
        let dateStr = dive.date.formatted(.dateTime.day().month(.abbreviated).year())
        let dateW = textSize(dateStr, size: 10, weight: .semibold).width
        drawText(dateStr, at: CGPoint(x: stripRect.maxX - 12 - dateW, y: stripRect.minY + 10),
                 size: 10, weight: .semibold, color: UIColor.white.withAlphaComponent(0.85))

        // Body split: left = key stats, right = conditions + buddies + notes preview
        let bodyY = stripRect.maxY + 10
        let midX = rect.midX
        let leftWidth = midX - rect.minX - 8
        let rightWidth = rect.maxX - midX - 8

        // LEFT: stats
        var ly = bodyY
        ly = drawCompactKV(label: loc("Max", "Max", lang),
                           value: String(format: "%.1f m", dive.maxDepth),
                           x: rect.minX + 12, y: ly, width: leftWidth)
        ly = drawCompactKV(label: loc("Zeit", "Time", lang),
                           value: "\(dive.totalTime) min",
                           x: rect.minX + 12, y: ly, width: leftWidth)
        ly = drawCompactKV(label: loc("Ø", "Avg", lang),
                           value: String(format: "%.1f m", dive.avgDepth),
                           x: rect.minX + 12, y: ly, width: leftWidth)
        ly = drawCompactKV(label: loc("Temp", "Temp", lang),
                           value: String(format: "%.0f°C", dive.waterTempSurface),
                           x: rect.minX + 12, y: ly, width: leftWidth)
        ly = drawCompactKV(label: loc("Sicht", "Viz", lang),
                           value: "\(dive.visibility) m",
                           x: rect.minX + 12, y: ly, width: leftWidth)
        ly = drawCompactKV(label: loc("Gas", "Gas", lang),
                           value: "\(dive.gas.uppercased()) · \(dive.tankStartBar)→\(dive.tankEndBar) bar",
                           x: rect.minX + 12, y: ly, width: leftWidth)

        // RIGHT: location, buddy, note
        var ry = bodyY
        ry = drawCompactKV(label: loc("Ort", "Location", lang),
                           value: dive.siteLocation.isEmpty ? "—" : dive.siteLocation,
                           x: midX + 8, y: ry, width: rightWidth)
        ry = drawCompactKV(label: loc("Center", "Center", lang),
                           value: dive.diveCenterName.isEmpty ? "—" : dive.diveCenterName,
                           x: midX + 8, y: ry, width: rightWidth)
        ry = drawCompactKV(label: loc("Typ", "Type", lang),
                           value: dive.diveType.capitalized,
                           x: midX + 8, y: ry, width: rightWidth)
        ry = drawCompactKV(label: loc("Buddy", "Buddy", lang),
                           value: dive.buddyNames.isEmpty ? "—" : dive.buddyNames,
                           x: midX + 8, y: ry, width: rightWidth)

        if !dive.notes.isEmpty {
            let noteY = max(ly, ry) + 6
            let availHeight = rect.maxY - noteY - 44 // reserve for signature line
            if availHeight > 20 {
                drawText(loc("Notizen", "Notes", lang).uppercased(),
                         at: CGPoint(x: rect.minX + 12, y: noteY),
                         size: 7, weight: .bold, color: inkSoft, tracking: 1.1)
                let noteRect = CGRect(x: rect.minX + 12, y: noteY + 12,
                                      width: rect.width - 24, height: availHeight)
                drawWrappedText(dive.notes, in: noteRect, size: 9, color: ink)
            }
        }

        // Signature line / stamp
        let sigY = rect.maxY - 34
        drawText(loc("Unterschrift Buddy", "Buddy Signature", lang).uppercased(),
                 at: CGPoint(x: rect.minX + 12, y: sigY),
                 size: 7, weight: .bold, color: inkSoft, tracking: 1.1)
        rule.setStroke()
        let line = UIBezierPath()
        line.move(to: CGPoint(x: rect.minX + 12, y: sigY + 24))
        line.addLine(to: CGPoint(x: rect.minX + 12 + 200, y: sigY + 24))
        line.lineWidth = 0.7
        line.stroke()

        // If signature exists, render it on the line
        if let firstSig = dive.signatures?.first, let data = firstSig.signatureImageData,
           let img = UIImage(data: data) {
            let imgRect = CGRect(x: rect.minX + 14, y: sigY + 2,
                                 width: 196, height: 22)
            img.draw(in: imgRect)
            drawText(firstSig.buddyName,
                     at: CGPoint(x: rect.minX + 12 + 208, y: sigY + 14),
                     size: 8, weight: .semibold, color: ink)
        }

        // Diver self-sign line (right side)
        let selfX = rect.maxX - 212
        drawText(loc("Taucher", "Diver", lang).uppercased(),
                 at: CGPoint(x: selfX, y: sigY),
                 size: 7, weight: .bold, color: inkSoft, tracking: 1.1)
        let line2 = UIBezierPath()
        line2.move(to: CGPoint(x: selfX, y: sigY + 24))
        line2.addLine(to: CGPoint(x: selfX + 200, y: sigY + 24))
        line2.lineWidth = 0.7
        line2.stroke()
    }

    // ═══════════════════════════════════════
    // MARK: - Cover & Summary

    private static func drawCover(dives: [Dive], profile: DiverProfile?, lang: String) {
        // Full deep-ocean background
        deepOcean.setFill()
        UIBezierPath(rect: CGRect(origin: .zero, size: pageSize)).fill()

        // Centered block
        let centerY = pageSize.height / 2 - 120

        drawText("ATOLLLOG",
                 at: CGPoint(x: margin, y: centerY),
                 size: 13, weight: .bold, color: seafoam, tracking: 4, center: true)

        let name = profile?.name.isEmpty == false ? profile!.name : loc("Dein Logbuch", "Your Logbook", lang)
        drawText(name,
                 at: CGPoint(x: margin, y: centerY + 36),
                 size: 32, weight: .bold, color: .white, center: true)

        // Cert line
        if let p = profile, !p.certLevel.isEmpty {
            drawText(prettyCert(p.certLevel) + (p.padiNumber.isEmpty ? "" : " · PADI #\(p.padiNumber)"),
                     at: CGPoint(x: margin, y: centerY + 82),
                     size: 13, weight: .regular, color: UIColor.white.withAlphaComponent(0.65), center: true)
        }

        // Stats strip
        let totalDives = dives.count
        let totalHours = dives.reduce(0) { $0 + $1.totalTime } / 60
        let deepest = dives.map(\.maxDepth).max() ?? 0
        let stats: [(String, String)] = [
            ("\(totalDives)", loc("Tauchgänge", "Dives", lang)),
            ("\(totalHours)h", loc("Unterwasser", "Underwater", lang)),
            (String(format: "%.0f m", deepest), loc("Tiefster", "Deepest", lang)),
        ]
        let strip0: CGFloat = centerY + 140
        let colW = (pageSize.width - 2 * margin) / CGFloat(stats.count)
        for (i, s) in stats.enumerated() {
            let cx = margin + colW * CGFloat(i) + colW / 2
            let valSize = textSize(s.0, size: 30, weight: .bold)
            drawText(s.0, at: CGPoint(x: cx - valSize.width / 2, y: strip0),
                     size: 30, weight: .bold, color: seafoam)
            let labSize = textSize(s.1.uppercased(), size: 9, weight: .semibold)
            drawText(s.1.uppercased(), at: CGPoint(x: cx - labSize.width / 2, y: strip0 + 38),
                     size: 9, weight: .semibold, color: UIColor.white.withAlphaComponent(0.55), tracking: 1.5)
        }

        // Date range
        if let earliest = dives.map(\.date).min(), let latest = dives.map(\.date).max() {
            let range = "\(earliest.formatted(.dateTime.month(.abbreviated).year())) — \(latest.formatted(.dateTime.month(.abbreviated).year()))"
            drawText(range,
                     at: CGPoint(x: margin, y: strip0 + 80),
                     size: 11, weight: .regular,
                     color: UIColor.white.withAlphaComponent(0.4), center: true)
        }

        // Footer: export date
        let exportedAt = Date().formatted(date: .long, time: .shortened)
        drawText(loc("Exportiert am ", "Exported on ", lang) + exportedAt,
                 at: CGPoint(x: margin, y: pageSize.height - 52),
                 size: 9, weight: .regular, color: UIColor.white.withAlphaComponent(0.3), center: true)
    }

    private static func drawSummary(dives: [Dive], profile: DiverProfile?, lang: String) {
        drawPageHeader(profile: profile, lang: lang)
        var y: CGFloat = margin + 40

        drawText(loc("Zusammenfassung", "Summary", lang),
                 at: CGPoint(x: margin, y: y),
                 size: 22, weight: .bold, color: ink)
        y += 34

        let totalDives = dives.count
        let totalMin = dives.reduce(0) { $0 + $1.totalTime }
        let deepest = dives.map(\.maxDepth).max() ?? 0
        let longest = dives.map(\.totalTime).max() ?? 0
        let avgDepth = dives.isEmpty ? 0 : dives.reduce(0.0) { $0 + $1.avgDepth } / Double(dives.count)
        let avgSac = dives.filter { $0.sacRate > 0 }.map(\.sacRate).reduce(0, +)
            / max(Double(dives.filter { $0.sacRate > 0 }.count), 1)
        let sites = Set(dives.map(\.siteName).filter { !$0.isEmpty }).count
        let buddies = Set(dives.flatMap(\.buddyList)).count
        let signed = dives.reduce(0) { $0 + ($1.signatures?.count ?? 0) }

        y = drawKeyValueGrid(items: [
            (loc("Gesamt-TGs", "Total Dives", lang), "\(totalDives)"),
            (loc("Unterwasser", "Underwater", lang), "\(totalMin / 60)h \(totalMin % 60)min"),
            (loc("Tiefster TG", "Deepest", lang), String(format: "%.1f m", deepest)),
            (loc("Längster TG", "Longest", lang), "\(longest) min"),
            (loc("Ø Tiefe", "Avg Depth", lang), String(format: "%.1f m", avgDepth)),
            (loc("Ø SAC", "Avg SAC", lang), String(format: "%.1f l/min", avgSac)),
            (loc("Spots", "Sites", lang), "\(sites)"),
            (loc("Buddies", "Buddies", lang), "\(buddies)"),
            (loc("Signaturen", "Signatures", lang), "\(signed)"),
        ], columns: 3, y: y)

        drawFooter(pageNumber: nil, totalPages: nil, profile: profile, lang: lang)
    }

    // ═══════════════════════════════════════
    // MARK: - Page Chrome (header/footer)

    private static func drawPageHeader(profile: DiverProfile?, lang: String) {
        // Small branded strip
        let ruleY: CGFloat = margin + 14
        let name = (profile?.name.isEmpty == false ? profile!.name : "AtollLog").uppercased()
        drawText(name,
                 at: CGPoint(x: margin, y: margin - 4),
                 size: 9, weight: .bold, color: inkSoft, tracking: 2)
        let rightLabel = "ATOLLLOG"
        let rw = textSize(rightLabel, size: 9, weight: .semibold).width
        drawText(rightLabel,
                 at: CGPoint(x: pageSize.width - margin - rw, y: margin - 4),
                 size: 9, weight: .semibold, color: oceanBlue, tracking: 2)
        // Thin rule
        oceanBlue.withAlphaComponent(0.3).setStroke()
        let p = UIBezierPath()
        p.move(to: CGPoint(x: margin, y: ruleY))
        p.addLine(to: CGPoint(x: pageSize.width - margin, y: ruleY))
        p.lineWidth = 0.5
        p.stroke()
    }

    private static func drawFooter(pageNumber: Int?, totalPages: Int?, profile: DiverProfile?, lang: String) {
        let y: CGFloat = pageSize.height - 28

        // Thin rule
        rule.setStroke()
        let p = UIBezierPath()
        p.move(to: CGPoint(x: margin, y: y))
        p.addLine(to: CGPoint(x: pageSize.width - margin, y: y))
        p.lineWidth = 0.5
        p.stroke()

        // Left: tiny PADI number
        if let padi = profile?.padiNumber, !padi.isEmpty {
            drawText("PADI #\(padi)",
                     at: CGPoint(x: margin, y: y + 8),
                     size: 8, weight: .regular, color: inkSoft)
        }

        // Center: brand
        let brand = "AtollLog"
        let bw = textSize(brand, size: 8, weight: .regular).width
        drawText(brand,
                 at: CGPoint(x: pageSize.width / 2 - bw / 2, y: y + 8),
                 size: 8, weight: .regular, color: inkSoft)

        // Right: page number
        if let n = pageNumber {
            let label: String
            if let total = totalPages { label = "\(n) / \(total)" }
            else { label = "\(n)" }
            let lw = textSize(label, size: 8, weight: .regular).width
            drawText(label,
                     at: CGPoint(x: pageSize.width - margin - lw, y: y + 8),
                     size: 8, weight: .regular, color: inkSoft)
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Section Helpers

    @discardableResult
    private static func drawSectionTitle(_ text: String, y: CGFloat) -> CGFloat {
        drawText(text.uppercased(),
                 at: CGPoint(x: margin, y: y),
                 size: 9, weight: .bold, color: oceanBlue, tracking: 1.5)
        // Underline rule
        oceanBlue.withAlphaComponent(0.25).setStroke()
        let p = UIBezierPath()
        p.move(to: CGPoint(x: margin, y: y + 14))
        p.addLine(to: CGPoint(x: pageSize.width - margin, y: y + 14))
        p.lineWidth = 0.5
        p.stroke()
        return y + 20
    }

    /// Flexible key/value grid: wraps to next row based on column count.
    @discardableResult
    private static func drawKeyValueGrid(items: [(String, String)], columns: Int, y: CGFloat) -> CGFloat {
        let available = pageSize.width - 2 * margin
        let colW = available / CGFloat(columns)
        let rowH: CGFloat = 30

        var cursorY = y
        for (i, item) in items.enumerated() {
            let col = i % columns
            let row = i / columns
            let x = margin + colW * CGFloat(col)
            let rectY = y + CGFloat(row) * rowH
            cursorY = rectY + rowH

            // Label
            drawText(item.0.uppercased(),
                     at: CGPoint(x: x, y: rectY),
                     size: 7, weight: .semibold, color: inkSoft, tracking: 1.1)
            // Value
            drawText(item.1,
                     at: CGPoint(x: x, y: rectY + 11),
                     size: 12, weight: .semibold, color: ink)
        }
        return cursorY + 4
    }

    /// Compact single-line KV used inside logbook slots.
    @discardableResult
    private static func drawCompactKV(label: String, value: String, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        drawText(label.uppercased(),
                 at: CGPoint(x: x, y: y),
                 size: 7, weight: .bold, color: inkSoft, tracking: 1.1)
        let labelW: CGFloat = 56
        let valueRect = CGRect(x: x + labelW, y: y - 1, width: width - labelW, height: 16)
        drawWrappedText(value, in: valueRect, size: 9.5, color: ink, maxLines: 1, bold: true)
        return y + 14
    }

    @discardableResult
    private static func drawParagraph(_ text: String, y: CGFloat, size: CGFloat) -> CGFloat {
        let rect = CGRect(x: margin, y: y, width: pageSize.width - 2 * margin,
                          height: pageSize.height - y - margin)
        let h = drawWrappedText(text, in: rect, size: size, color: ink)
        return y + h + 4
    }

    @discardableResult
    private static func drawTagWrap(_ tags: [String], y: CGFloat) -> CGFloat {
        var x: CGFloat = margin
        var cy: CGFloat = y
        let maxX = pageSize.width - margin
        let padH: CGFloat = 8
        let padV: CGFloat = 4
        let gap: CGFloat = 6
        for tag in tags {
            let tw = textSize(tag, size: 10, weight: .semibold).width
            let chipW = tw + padH * 2
            if x + chipW > maxX {
                x = margin
                cy += 24
            }
            let chipRect = CGRect(x: x, y: cy, width: chipW, height: 18)
            seafoam.withAlphaComponent(0.18).setFill()
            UIBezierPath(roundedRect: chipRect, cornerRadius: 9).fill()
            drawText(tag,
                     at: CGPoint(x: x + padH, y: cy + padV),
                     size: 10, weight: .semibold, color: deepOcean)
            x += chipW + gap
        }
        return cy + 18 + 2
    }

    @discardableResult
    private static func drawSignatureBlock(_ sig: DiveSignature, y: CGFloat) -> CGFloat {
        let h: CGFloat = 64
        let rect = CGRect(x: margin, y: y, width: pageSize.width - 2 * margin, height: h)
        sandLight.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 8).fill()

        // Name + PADI
        drawText(sig.buddyName,
                 at: CGPoint(x: rect.minX + 12, y: rect.minY + 10),
                 size: 11, weight: .bold, color: ink)
        if !sig.buddyPadiNumber.isEmpty {
            drawText("PADI #\(sig.buddyPadiNumber)",
                     at: CGPoint(x: rect.minX + 12, y: rect.minY + 26),
                     size: 9, weight: .regular, color: inkSoft, design: .monospaced)
        }
        let dateStr = sig.signedAt.formatted(.dateTime.day().month().year())
        drawText(dateStr,
                 at: CGPoint(x: rect.minX + 12, y: rect.minY + 40),
                 size: 8, weight: .regular, color: inkSoft)

        // Signature image
        if let data = sig.signatureImageData, let img = UIImage(data: data) {
            let imgRect = CGRect(x: rect.maxX - 200 - 10, y: rect.minY + 6,
                                 width: 200, height: h - 12)
            UIColor.white.setFill()
            UIBezierPath(roundedRect: imgRect, cornerRadius: 4).fill()
            img.draw(in: imgRect.insetBy(dx: 2, dy: 2))
        }

        return rect.maxY
    }

    // ═══════════════════════════════════════
    // MARK: - Text Drawing

    private static func drawText(_ text: String, at origin: CGPoint,
                                 size: CGFloat, weight: UIFont.Weight,
                                 color: UIColor,
                                 design: UIFontDescriptor.SystemDesign = .default,
                                 tracking: CGFloat = 0,
                                 center: Bool = false) {
        var font: UIFont
        if design == .monospaced {
            font = .monospacedSystemFont(ofSize: size, weight: weight)
        } else {
            font = .systemFont(ofSize: size, weight: weight)
        }

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        if tracking > 0 {
            attrs[.kern] = tracking
        }

        let attr = NSAttributedString(string: text, attributes: attrs)
        if center {
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            var centerAttrs = attrs
            centerAttrs[.paragraphStyle] = para
            let centered = NSAttributedString(string: text, attributes: centerAttrs)
            let rect = CGRect(x: margin, y: origin.y,
                              width: pageSize.width - 2 * margin, height: size * 1.6)
            centered.draw(in: rect)
        } else {
            attr.draw(at: origin)
        }
    }

    private static func textSize(_ text: String, size: CGFloat, weight: UIFont.Weight) -> CGSize {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        return (text as NSString).size(withAttributes: [.font: font])
    }

    @discardableResult
    private static func drawWrappedText(_ text: String, in rect: CGRect, size: CGFloat, color: UIColor,
                                        maxLines: Int = 0, bold: Bool = false) -> CGFloat {
        let font = UIFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: para,
        ]
        let attr = NSAttributedString(string: text, attributes: attrs)

        if maxLines == 1 {
            // Single-line truncation
            attr.draw(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: font.lineHeight + 2))
            return font.lineHeight
        }

        // Multi-line: use CoreText via attributed draw(with:) for bounding box
        let bounds = attr.boundingRect(
            with: CGSize(width: rect.width, height: rect.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        attr.draw(with: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: bounds.height),
                  options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return bounds.height
    }

    // ═══════════════════════════════════════
    // MARK: - Locale helpers

    private static func loc(_ de: String, _ en: String, _ lang: String) -> String {
        lang == "de" ? de : en
    }

    private static func formatSuit(_ raw: String) -> String {
        switch raw {
        case "shorty":  return "Shorty"
        case "3mm":     return "3 mm"
        case "5mm":     return "5 mm"
        case "7mm":     return "7 mm"
        case "semi_dry": return "Semi-Dry"
        case "drysuit": return "Drysuit"
        case "none":    return "—"
        default:        return raw.capitalized
        }
    }

    private static func prettyCert(_ raw: String) -> String {
        switch raw {
        case "CD": return "PADI Course Director"
        case "IDC Staff": return "IDC Staff Instructor"
        case "MSDT": return "Master Scuba Diver Trainer"
        case "OWSI": return "Open Water Scuba Instructor"
        case "DM": return "Divemaster"
        case "Rescue": return "Rescue Diver"
        case "AOWD": return "Advanced Open Water"
        case "OWD": return "Open Water Diver"
        default: return raw
        }
    }

    // ═══════════════════════════════════════
    // MARK: - PDF Metadata

    private static func pdfFormat(title: String, author: String) -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextAuthor as String: author,
            kCGPDFContextCreator as String: "AtollLog",
        ]
        return format
    }
}

// ═══════════════════════════════════════
// MARK: - CSV Exporter
// ═══════════════════════════════════════

enum CSVExporter {
    /// RFC-4180 CSV of all dive data. One row per dive. Good for spreadsheet
    /// post-processing or migration to other logbook apps.
    static func export(_ dives: [Dive], languageCode lang: String) -> String {
        let header = [
            "number", "date", "time", "diveType",
            "siteName", "siteLocation", "latitude", "longitude", "diveCenter",
            "maxDepth_m", "avgDepth_m", "bottomTime_min", "totalTime_min", "safetyStop_min", "entry",
            "weather", "airTemp_C", "waterTempSurface_C", "waterTempBottom_C",
            "visibility_m", "current", "waves", "waterType",
            "suit", "weight_kg", "weightFeel",
            "cylinderType", "cylinderSize_L", "gas",
            "tankStart_bar", "tankEnd_bar", "tankUsed_bar", "sacRate_lpm",
            "computer", "algorithm", "gradientFactors",
            "n2Start_pct", "n2End_pct", "cnsStart_pct", "cnsEnd_pct",
            "hrAvg", "hrMax", "calories",
            "feeling", "rating", "highlight",
            "buddies", "marineLife", "notes",
            "signatureCount",
        ]

        var out = header.map(csvField).joined(separator: ",") + "\n"

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate]
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HH:mm"

        for d in dives.sorted(by: { $0.date < $1.date }) {
            let row: [String] = [
                "\(d.number)",
                iso.string(from: d.date),
                timeFmt.string(from: d.date),
                d.diveType,
                d.siteName,
                d.siteLocation,
                "\(d.latitude)",
                "\(d.longitude)",
                d.diveCenterName,
                String(format: "%.1f", d.maxDepth),
                String(format: "%.1f", d.avgDepth),
                "\(d.bottomTime)",
                "\(d.totalTime)",
                "\(d.safetyStopMin)",
                d.entryType,
                d.weather,
                String(format: "%.1f", d.airTemp),
                String(format: "%.1f", d.waterTempSurface),
                String(format: "%.1f", d.waterTempBottom),
                "\(d.visibility)",
                d.current, d.waves, d.waterType,
                d.suit, String(format: "%.1f", d.weightKg), d.weightFeel,
                d.cylinderType, String(format: "%.1f", d.cylinderSizeLiters), d.gas,
                "\(d.tankStartBar)", "\(d.tankEndBar)", "\(d.tankUsed)", String(format: "%.1f", d.sacRate),
                d.computerModel, d.algorithm, d.gradientFactors,
                "\(d.n2LoadStart)", "\(d.n2LoadEnd)", "\(d.cnsStart)", "\(d.cnsEnd)",
                "\(d.hrAvg)", "\(d.hrMax)", "\(d.calories)",
                d.feeling, "\(d.rating)", d.isHighlight ? "true" : "false",
                d.buddyNames,
                d.marineLife.joined(separator: "; "),
                d.notes.replacingOccurrences(of: "\n", with: " "),
                "\(d.signatures?.count ?? 0)",
            ]
            out += row.map(csvField).joined(separator: ",") + "\n"
        }
        _ = lang // reserved for future localized headers
        return out
    }

    /// Escape a field per RFC 4180: wrap in quotes if it contains comma,
    /// quote, or newline; double-up any embedded quotes.
    private nonisolated static func csvField(_ s: String) -> String {
        let needsQuote = s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r")
        if !needsQuote { return s }
        let escaped = s.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
