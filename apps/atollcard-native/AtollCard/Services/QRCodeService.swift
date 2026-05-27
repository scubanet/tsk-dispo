import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import SwiftUI
import AtollDesign

/// Generates QR codes for card URLs.
///
/// Correction level "H" (30% restoration) gives us enough redundancy to
/// overlay an ATOLL logo in the middle without breaking scanability. We
/// upscale the raw 25×25-ish output to 1024 with `CGAffineTransform` and
/// `.nearestNeighbor` so the modules render as sharp squares.
public enum QRCodeService {

  public static func image(for url: URL, size: CGFloat = 1024) -> UIImage? {
    image(for: url.absoluteString, size: size)
  }

  public static func image(for string: String, size: CGFloat = 1024) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "H"
    guard let output = filter.outputImage else { return nil }

    // Scale up to the desired pixel size.
    let scale = size / output.extent.width
    let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

    let context = CIContext()
    guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
    return UIImage(cgImage: cgImage)
  }
}

/// SwiftUI wrapper — drops in a QR image for a URL, with optional logo overlay.
public struct QRCodeView: View {
  let url: URL
  var showsLogo: Bool = true
  var logoFraction: CGFloat = 0.22       // logo width as fraction of QR

  public init(url: URL, showsLogo: Bool = true, logoFraction: CGFloat = 0.22) {
    self.url = url
    self.showsLogo = showsLogo
    self.logoFraction = logoFraction
  }

  public var body: some View {
    GeometryReader { geo in
      let side = min(geo.size.width, geo.size.height)
      ZStack {
        if let img = QRCodeService.image(for: url, size: side * 3) {
          Image(uiImage: img)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
        } else {
          Color.gray.opacity(0.2)
            .overlay(Text("QR-Fehler").foregroundStyle(.secondary))
        }
        if showsLogo {
          AtollCardLogo(size: side * logoFraction)
            .padding(side * logoFraction * 0.12)
            .background(
              RoundedRectangle(cornerRadius: side * logoFraction * 0.22)
                .fill(.white)
            )
        }
      }
      .frame(width: side, height: side)
    }
    .aspectRatio(1, contentMode: .fit)
  }
}

#Preview {
  VStack {
    QRCodeView(url: URL(string: "https://atoll-os.com/c/dominik-cd")!)
      .frame(width: 240, height: 240)
    Text("atoll-os.com/c/dominik-cd")
      .font(.system(.footnote, design: .monospaced))
  }
  .padding()
}
