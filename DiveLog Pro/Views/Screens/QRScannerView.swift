import SwiftUI
import AVFoundation
import AudioToolbox

// ═══════════════════════════════════════
// MARK: - QR Scanner View
// ═══════════════════════════════════════
//
// Live camera QR scanner. Calls `onFound` exactly once with the raw string,
// then dismisses. Includes torch toggle and a targeting frame.
//
struct QRScannerView: View {
    let onFound: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var torchOn = false

    var body: some View {
        ZStack {
            ScannerRepresentable(torchOn: $torchOn) { code in
                onFound(code)
                dismiss()
            }
            .ignoresSafeArea()

            // ─── Overlay UI ───────────────
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }

                    Spacer()

                    Button {
                        torchOn.toggle()
                    } label: {
                        Image(systemName: torchOn ? "bolt.fill" : "bolt.slash")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                }
                .padding(.horizontal, DSSpacing.l)
                .padding(.top, DSSpacing.m)

                Spacer()

                // Targeting frame
                RoundedRectangle(cornerRadius: DSRadius.l)
                    .stroke(Color.appAccent, lineWidth: 3)
                    .frame(width: 240, height: 240)
                    .shadow(color: Color.appAccent.opacity(0.5), radius: 8)

                Spacer()

                Text(L10n.scanHint)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.black.opacity(0.6)))
                    .padding(.bottom, DSSpacing.xxl)
            }
        }
    }
}

// ═══════════════════════════════════════
// MARK: - UIViewControllerRepresentable
// ═══════════════════════════════════════

private struct ScannerRepresentable: UIViewControllerRepresentable {
    @Binding var torchOn: Bool
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onCode = onCode
        return vc
    }

    func updateUIViewController(_ vc: ScannerVC, context: Context) {
        vc.setTorch(torchOn)
    }
}

// ═══════════════════════════════════════
// MARK: - Camera VC
// ═══════════════════════════════════════

final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var didFire = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        preview = layer
    }

    func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch
        else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            // Torch unavailable — silently ignore.
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !didFire,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let str = obj.stringValue
        else { return }

        didFire = true
        AudioServicesPlaySystemSound(1057) // confirmation tock
        onCode?(str)
    }
}
