import SwiftUI
import AVFoundation
import Combine

// Queue confinement provides Sendable safety: session/output/configured use `queue`;
// published state, request IDs, and pending callbacks use the main queue only.
final class RecyclingCamera: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    @Published private(set) var ready = false
    @Published private(set) var starting = false
    @Published private(set) var capturing = false
    @Published private(set) var message: String?
    @Published private(set) var interruptionCount = 0

    private let queue = DispatchQueue(label: "org.recycli.camera")
    private let output = AVCapturePhotoOutput()
    private var configured = false // session queue only
    private var requestID = UUID() // main queue only
    private var pendingID: Int64?
    private var onPhoto: ((UIImage, Date) -> Void)?
    private var capturedAt = Date()
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        for name in [AVCaptureSession.wasInterruptedNotification, AVCaptureSession.runtimeErrorNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: session, queue: .main) { [weak self] _ in
                self?.stop()
                self?.message = "The camera was interrupted. Start a fresh capture to keep both photos together."
                self?.interruptionCount += 1
            })
        }
    }
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !ready, !starting else { return }
        starting = true
        let id = UUID()
        requestID = id
        message = nil
        Task { @MainActor [weak self] in
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            guard let self, self.requestID == id else { return }
            guard allowed else {
                self.starting = false
                self.message = "Camera access is off. Enable Recycli’s Camera permission in iPhone Settings."
                return
            }
            self.queue.async { [weak self] in
                guard let self else { return }
                do {
                    if !self.configured { try self.configure() }
                    if !self.session.isRunning { self.session.startRunning() }
                    let running = self.session.isRunning
                    DispatchQueue.main.async {
                        guard self.requestID == id else { return }
                        self.starting = false
                        self.ready = running
                        if !running { self.message = "The camera couldn’t start. Tap Try camera again." }
                    }
                } catch {
                    DispatchQueue.main.async {
                        guard self.requestID == id else { return }
                        self.starting = false
                        self.message = error.localizedDescription
                    }
                }
            }
        }
    }

    private func configure() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw VerificationError.message("A rear camera is required. On a simulator, use Dev → Tools → Guided capture demo.")
        }
        let input = try AVCaptureDeviceInput(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard session.canAddInput(input) else { throw VerificationError.message("The camera input isn’t available.") }
        session.addInput(input)
        guard session.canAddOutput(output) else {
            session.removeInput(input)
            throw VerificationError.message("Photo capture isn’t available.")
        }
        session.addOutput(output)
        output.maxPhotoQualityPrioritization = .balanced
        configured = true
    }

    func capture(_ completion: @escaping (UIImage, Date) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard ready, !capturing else { return }
        capturing = true
        message = nil
        onPhoto = completion
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        // Small recognition photos benefit more from prompt delivery than extra processing.
        settings.photoQualityPrioritization = .speed
        pendingID = settings.uniqueID
        capturedAt = Date()
        queue.async { [weak self] in
            guard let self else { return }
            if let connection = self.output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    func stop() {
        dispatchPrecondition(condition: .onQueue(.main))
        requestID = UUID()
        pendingID = nil
        onPhoto = nil
        ready = false
        starting = false
        capturing = false
        // Keep the session owner alive until shutdown, even if its SwiftUI view is dismissed.
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let bytes = error == nil ? photo.fileDataRepresentation() : nil
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pendingID == photo.resolvedSettings.uniqueID else { return }
            self.pendingID = nil
            self.capturing = false
            let callback = self.onPhoto
            self.onPhoto = nil
            guard let bytes, let image = UIImage(data: bytes) else {
                self.message = "That photo couldn’t be captured. Keep the camera open and try again."
                return
            }
            callback?(image, self.capturedAt)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        guard error != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.pendingID == resolvedSettings.uniqueID else { return }
            self.pendingID = nil
            self.onPhoto = nil
            self.capturing = false
            self.message = "The capture didn’t finish. Please try again."
        }
    }
}

struct RecyclingCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> CameraPreviewSurface {
        let view = CameraPreviewSurface()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }
    func updateUIView(_ view: CameraPreviewSurface, context: Context) { view.setNeedsLayout() }
}

final class CameraPreviewSurface: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }
}
