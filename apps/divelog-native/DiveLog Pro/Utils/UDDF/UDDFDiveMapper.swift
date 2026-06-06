import Foundation

/// Translates a UDDF-parsed dive into a SwiftData `Dive` object ready to
/// be inserted. Applies defaults for fields UDDF doesn't carry and
/// resolves site/gas references against the parent UDDFFile.
enum UDDFDiveMapper {

    /// Max number of points kept in `Dive.depthProfile`. Sample arrays
    /// larger than this are uniformly down-sampled. 200 points is enough
    /// for a smooth chart and small enough to keep CloudKit sync cheap.
    static let maxProfilePoints = 200

    static func makeDive(from uddf: UDDFDive, in file: UDDFFile) -> Dive {
        let totalMin = Int((Double(uddf.durationSeconds) / 60.0).rounded())
        let site = uddf.siteRef.flatMap { file.diveSites[$0] }
        let gas = uddf.gasRef.flatMap { file.gasDefinitions[$0] }

        let (surfaceTemp, bottomTemp) = aggregateTemperatures(uddf.samples)
        let profile = downsampleDepthProfile(uddf.samples)

        return Dive(
            number: 0,
            date: uddf.datetime,
            diveType: "fun",                          // default; user can change after import
            siteName: site?.name ?? "",
            siteLocation: "",                         // UDDF has no city/country split
            latitude: site?.latitude ?? 0,
            longitude: site?.longitude ?? 0,
            diveCenterName: "",
            maxDepth: uddf.maxDepthMeters,
            avgDepth: uddf.avgDepthMeters,
            bottomTime: totalMin,                    // UDDF doesn't separate bottom vs total
            totalTime: totalMin,
            waterTempSurface: surfaceTemp,
            waterTempBottom: bottomTemp,
            weightKg: uddf.leadKg ?? 2,
            cylinderSizeLiters: uddf.tankVolumeLiters ?? 12,
            gas: discretizeGas(gas),
            tankStartBar: uddf.tankStartBar ?? 200,
            tankEndBar: uddf.tankEndBar ?? 50,
            notes: uddf.notes ?? "",
            depthProfile: profile
        )
    }

    // MARK: - Helpers

    /// Maps a UDDFGas (with o2/he fractions) to one of Dive.gas's
    /// canonical strings. Buckets at standard nitrox values, falls
    /// back to "air" if helium is zero and o2 ≈ 0.21.
    static func discretizeGas(_ gas: UDDFGas?) -> String {
        guard let gas else { return "air" }
        if gas.he > 0.001 { return "trimix" }
        switch gas.o2 {
        case 0.19..<0.22:  return "air"
        case 0.30..<0.34:  return "eanx32"
        case 0.34..<0.38:  return "eanx36"
        case 0.38..<0.42:  return "eanx40"
        default:           return "air"
        }
    }

    /// Returns (surfaceTemp, bottomTemp). Surface = max observed
    /// (warmest at the surface during entry/exit). Bottom = min
    /// observed. Falls back to App defaults (28 / 27 °C) if no
    /// temperature samples.
    static func aggregateTemperatures(_ samples: [UDDFSample]) -> (surface: Double, bottom: Double) {
        let temps = samples.compactMap(\.temperatureCelsius)
        guard !temps.isEmpty else { return (28, 27) }
        return (surface: temps.max() ?? 28, bottom: temps.min() ?? 27)
    }

    /// Uniform down-sample of the depth-vs-time series to at most
    /// `maxProfilePoints` entries. Preserves the first and last samples.
    static func downsampleDepthProfile(_ samples: [UDDFSample]) -> [Double] {
        let depths = samples.map(\.depthMeters)
        guard depths.count > maxProfilePoints else { return depths }

        let stride = Double(depths.count - 1) / Double(maxProfilePoints - 1)
        return (0..<maxProfilePoints).map { i in
            let idx = min(Int((Double(i) * stride).rounded()), depths.count - 1)
            return depths[idx]
        }
    }
}
