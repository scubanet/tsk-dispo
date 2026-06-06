import SwiftUI
import UIKit

// ═══════════════════════════════════════
// MARK: - Signature Canvas
// ═══════════════════════════════════════

/// Finger-drawn signature capture. Uses SwiftUI Canvas for rendering and
/// DragGesture for input. Strokes are stored as arrays of CGPoint so the
/// caller can render them back to a UIImage for persistence.
struct SignatureCanvas: View {
    @Binding var strokes: [[CGPoint]]
    var strokeColor: Color = .black
    var strokeWidth: CGFloat = 2.5
    var backgroundColor: Color = .white

    @State private var currentStroke: [CGPoint] = []

    var body: some View {
        Canvas { ctx, _ in
            // Existing strokes
            for stroke in strokes {
                drawStroke(stroke, in: ctx)
            }
            // In-progress stroke
            if !currentStroke.isEmpty {
                drawStroke(currentStroke, in: ctx)
            }
        }
        .background(backgroundColor)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    currentStroke.append(value.location)
                }
                .onEnded { _ in
                    if currentStroke.count > 1 {
                        strokes.append(currentStroke)
                    }
                    currentStroke = []
                }
        )
    }

    private func drawStroke(_ stroke: [CGPoint], in ctx: GraphicsContext) {
        guard stroke.count > 1 else { return }
        var path = Path()
        path.move(to: stroke[0])
        for pt in stroke.dropFirst() {
            path.addLine(to: pt)
        }
        ctx.stroke(
            path,
            with: .color(strokeColor),
            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
        )
    }
}

// ═══════════════════════════════════════
// MARK: - Render Helper
// ═══════════════════════════════════════

enum SignatureRenderer {
    /// Renders strokes to a UIImage at the given size. Used to persist the
    /// signature as PNG data in the DiveSignature model.
    static func render(
        strokes: [[CGPoint]],
        size: CGSize,
        background: UIColor = .white,
        strokeColor: UIColor = .black,
        lineWidth: CGFloat = 2.5
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UITraitCollection.current.displayScale
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { rendererCtx in
            let ctx = rendererCtx.cgContext
            background.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            strokeColor.setStroke()
            ctx.setLineWidth(lineWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            for stroke in strokes where stroke.count > 1 {
                ctx.move(to: stroke[0])
                for pt in stroke.dropFirst() {
                    ctx.addLine(to: pt)
                }
                ctx.strokePath()
            }
        }
    }

    /// Convenience: strokes → PNG data ready for SwiftData storage.
    static func pngData(strokes: [[CGPoint]], size: CGSize) -> Data? {
        let img = render(strokes: strokes, size: size)
        return img.pngData()
    }
}
