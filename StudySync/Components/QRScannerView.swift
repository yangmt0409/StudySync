import SwiftUI
import AVFoundation

/// Full-screen QR code scanner. Calls `onCode` once with the first detected
/// payload, then the caller is expected to dismiss the sheet.
///
/// Handles camera permission prompt + denied state inline so the parent
/// view does not need to know about AVFoundation.
struct QRScannerView: View {
    let onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var permission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var scannedCode: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch permission {
                case .authorized:
                    scannerContent
                case .notDetermined:
                    requestView
                case .denied, .restricted:
                    deniedView
                @unknown default:
                    deniedView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(L10n.qrScanTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Content States

    private var scannerContent: some View {
        ZStack {
            QRScannerRepresentable { code in
                guard scannedCode == nil else { return }
                scannedCode = code
                HapticEngine.shared.success()
                onCode(code)
            }
            .ignoresSafeArea()

            // Viewfinder overlay
            VStack {
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.9), lineWidth: 3)
                        .frame(width: 260, height: 260)
                    // Corner accents
                    ForEach(0..<4) { i in
                        cornerAccent
                            .rotationEffect(.degrees(Double(i) * 90))
                            .offset(
                                x: (i == 0 || i == 3) ? -130 : 130,
                                y: (i < 2) ? -130 : 130
                            )
                    }
                }
                Spacer()
                Text(L10n.qrScanHint)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, 60)
            }
        }
    }

    private var cornerAccent: some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 20))
            p.addLine(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: 20, y: 0))
        }
        .stroke(Color(hex: "#5B7FFF"), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        .frame(width: 20, height: 20)
    }

    private var requestView: some View {
        VStack(spacing: 18) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.8))
            Text(L10n.qrPermissionPrompt)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        permission = granted ? .authorized : .denied
                    }
                }
            } label: {
                Text(L10n.qrAllowCamera)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color(hex: "#5B7FFF")))
            }
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.7))
            Text(L10n.qrPermissionDenied)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text(L10n.qrOpenSettings)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color(hex: "#5B7FFF")))
            }
        }
    }
}

// MARK: - AVFoundation Wrapper

struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let vc = QRScannerController()
        vc.onCode = onCode
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) {}
}

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasReported = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        self.previewLayer = preview
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasReported,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let string = obj.stringValue else { return }
        hasReported = true
        onCode?(string)
    }
}
