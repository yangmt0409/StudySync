import SwiftUI
import AVFoundation

/// Camera-based barcode scanner supporting both PDF417 (airline boarding passes)
/// and QR (Chinese rail tickets + generic). Reuses the camera permission already
/// granted for QR project invites.
struct TravelBarcodeScanner: View {
    /// Callback with raw payload + detected format. Caller decides how to parse.
    var onScan: (String, BarcodeFormat) -> Void

    var body: some View {
        ZStack {
            BarcodeScannerRepresentable(onScan: onScan)
                .ignoresSafeArea()
            GeometryReader { geo in
                let size = min(min(geo.size.width, geo.size.height) * 0.7, 480)
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
                        .frame(width: size, height: size * 0.5)  // wider for PDF417
                    Spacer()
                    Text(String(localized: "对准登机牌条码或车票 QR"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 60)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - UIKit representable

struct BarcodeScannerRepresentable: UIViewControllerRepresentable {
    var onScan: (String, BarcodeFormat) -> Void

    func makeUIViewController(context: Context) -> BarcodeScannerVC {
        let vc = BarcodeScannerVC()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerVC, context: Context) {}
}

final class BarcodeScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String, BarcodeFormat) -> Void)?

    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    private var hasFired = false
    /// True once the view is no longer visible — any in-flight session start
    /// should bail out instead of starting a session we're about to tear down.
    private var isDismissing = false
    /// Dedicated queue for session state changes. Prevents a race where
    /// `startRunning` runs after `stopRunning` from the main thread.
    private let sessionQueue = DispatchQueue(label: "studysync.barcode.session")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isDismissing = false
        sessionQueue.async { [weak self] in
            guard let self, !self.isDismissing, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isDismissing = true
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.beginConfiguration()
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            // Accept both PDF417 (airline) and QR (rail + generic)
            let preferred: [AVMetadataObject.ObjectType] = [.pdf417, .qr, .aztec]
            let available = preferred.filter { output.availableMetadataObjectTypes.contains($0) }
            output.metadataObjectTypes = available
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        self.preview = preview

        session.commitConfiguration()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasFired,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let payload = obj.stringValue else { return }
        let format: BarcodeFormat = {
            switch obj.type {
            case .pdf417: return .pdf417
            case .qr:     return .qr
            default:      return .other
            }
        }()
        hasFired = true
        onScan?(payload, format)
    }
}
