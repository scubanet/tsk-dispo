import Foundation
import SwiftData

@Model
final class DivePhoto {
    var filename: String = ""
    var imageData: Data = Data()
    var capturedAt: Date = Date()

    @Relationship var dive: Dive?

    init() {}
}
