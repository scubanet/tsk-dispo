import Foundation

struct SampleData {
    
    static func generateProfile(maxDepth: Double, duration: Int) -> [Double] {
        var pts: [Double] = []
        let total = 60
        for i in 0...total {
            let t = Double(i) / Double(total)
            var d: Double
            if t < 0.08 { d = t / 0.08 * maxDepth * 0.95 }
            else if t < 0.15 { d = maxDepth * 0.95 + (t - 0.08) / 0.07 * maxDepth * 0.05 }
            else if t < 0.75 {
                d = maxDepth * (0.85 + 0.15 * sin((t - 0.15) / 0.6 * .pi * 3) * 0.3)
                d += Double.random(in: -0.5...0.5) * maxDepth * 0.08
            }
            else if t < 0.85 { d = maxDepth * 0.85 * (1 - (t - 0.75) / 0.1 * 0.6) }
            else if t < 0.92 { d = maxDepth * 0.85 * 0.4 + Double.random(in: -0.25...0.25) }
            else { d = maxDepth * 0.85 * 0.4 * (1 - (t - 0.92) / 0.08) }
            pts.append(max(0, min(maxDepth * 1.05, d)))
        }
        return pts
    }
    
    static func createSampleDives() -> [Dive] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        
        let d1 = Dive(
            number: 8757, date: df.date(from: "2026-03-12 14:25") ?? .now,
            diveType: "training",
            siteName: "Mamutic Island", siteLocation: "Kota Kinabalu, Malaysia",
            latitude: 5.97, longitude: 116.01, diveCenterName: "CDTC",
            maxDepth: 11.2, avgDepth: 8.9, bottomTime: 62, totalTime: 66,
            entryType: "boat", weather: "sunny", airTemp: 31,
            waterTempSurface: 28, waterTempBottom: 27, visibility: 12, current: "light",
            suit: "shorty", weightKg: 2,
            cylinderType: "aluminum", cylinderSizeLiters: 12.2,
            tankStartBar: 188, tankEndBar: 48, sacRate: 12.58,
            computerModel: "Garmin Descent MK3i", algorithm: "Bühlmann ZHL-16C", gradientFactors: "40/85",
            n2LoadEnd: 57, hrAvg: 93, hrMax: 127, calories: 313,
            feeling: "good",
            buddyNames: "Green means Go Team",
            marineLife: ["Clownfish", "Sea Turtle", "Moray Eel"]
        )
        d1.depthProfile = generateProfile(maxDepth: 11.2, duration: 66)
        d1.notes = "OW Training dive with candidates. Rescue 7."
        
        let d2 = Dive(
            number: 8756, date: df.date(from: "2026-03-12 10:15") ?? .now,
            diveType: "training",
            siteName: "Sapi Island Reef", siteLocation: "Kota Kinabalu, Malaysia",
            latitude: 6.00, longitude: 116.00, diveCenterName: "CDTC",
            maxDepth: 8.5, avgDepth: 6.2, bottomTime: 48, totalTime: 52,
            entryType: "boat", weather: "sunny", airTemp: 30,
            waterTempSurface: 29, waterTempBottom: 28, visibility: 15,
            suit: "none", weightKg: 2,
            tankStartBar: 200, tankEndBar: 80, sacRate: 11.2,
            computerModel: "Garmin Descent MK3i", algorithm: "Bühlmann ZHL-16C", gradientFactors: "40/85",
            n2LoadEnd: 38, hrAvg: 88, hrMax: 112, calories: 245,
            feeling: "amazing", rating: 5, isHighlight: true,
            buddyNames: "Green means Go Team",
            marineLife: ["Nemo", "Parrotfish", "Blue Starfish"]
        )
        d2.depthProfile = generateProfile(maxDepth: 8.5, duration: 52)
        d2.notes = "First OW training dive of the CDTC. Perfect conditions, crystal clear water."
        
        let d3 = Dive(
            number: 8728, date: df.date(from: "2025-02-25 11:22") ?? .now,
            diveType: "fun",
            siteName: "Dapdap", siteLocation: "Anda, Bohol, Philippines",
            latitude: 9.75, longitude: 124.58, diveCenterName: "Amun Ini",
            maxDepth: 24.2, avgDepth: 16.05, bottomTime: 46, totalTime: 49,
            entryType: "boat", weather: "sunny", airTemp: 30,
            waterTempSurface: 28, waterTempBottom: 26, visibility: 20, current: "moderate",
            suit: "shorty", cylinderSizeLiters: 12.2,
            tankStartBar: 202, tankEndBar: 67, sacRate: 12.58,
            computerModel: "Shearwater Teric", algorithm: "Bühlmann ZHL-16C", gradientFactors: "40/85",
            n2LoadEnd: 57, cnsEnd: 16, hrAvg: 93, hrMax: 127, calories: 313,
            feeling: "amazing", rating: 5, isHighlight: true,
            buddyNames: "Lance Lagria, Jeryll Weckherlin",
            marineLife: ["Whale Shark", "Manta Ray", "Barracuda School"]
        )
        d3.depthProfile = generateProfile(maxDepth: 24.2, duration: 49)
        d3.notes = "Wiederholungs-TG mit Lance und Jeryll. Fantastische Sicht, dann plötzlich: Walhai! Direkt an uns vorbei geschwommen, geschätzt 6 Meter lang. Unvergesslich."
        
        let d4 = Dive(
            number: 8650, date: df.date(from: "2023-08-04 09:30") ?? .now,
            diveType: "fun",
            siteName: "PPB Alona Beach", siteLocation: "Panglao, Bohol, Philippines",
            latitude: 9.55, longitude: 123.77,
            maxDepth: 12, avgDepth: 8.5, bottomTime: 45, totalTime: 48,
            entryType: "boat", weather: "sunny", airTemp: 30,
            waterTempSurface: 30, waterTempBottom: 28, visibility: 18, current: "light",
            suit: "shorty",
            tankStartBar: 200, tankEndBar: 70, sacRate: 13.1,
            computerModel: "Shearwater Teric", algorithm: "Bühlmann ZHL-16C", gradientFactors: "40/85",
            n2LoadEnd: 42, hrAvg: 95, hrMax: 118, calories: 280,
            feeling: "good", rating: 4,
            buddyNames: "Jai, Lance",
            marineLife: ["Nudibranch", "Lionfish", "Giant Clam"]
        )
        d4.depthProfile = generateProfile(maxDepth: 12, duration: 48)
        d4.notes = "Zweiter TG mit Jai und Lance. Toller Tag am Alona Beach. Jai hat seinen ersten Nudibranch entdeckt — seine Begeisterung war ansteckend!"
        
        return [d1, d2, d3, d4]
    }
}
