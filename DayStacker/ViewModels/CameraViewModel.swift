import AVFoundation
import UIKit
import Combine

@MainActor
final class CameraViewModel: NSObject, ObservableObject {

    @Published var captureState: CaptureState = .idle
    @Published var lastError: String?

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let extractor = SubjectExtractor()

    private var onCapture: ((UIImage, Double) async -> Void)?

    enum CaptureState: Equatable {
        case idle, capturing, extracting
    }

    // MARK: - Session setup

    func configure(onCapture: @escaping (UIImage, Double) async -> Void) {
        self.onCapture = onCapture
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await self.setupSession()
        }
    }

    private func setupSession() async {
        guard await requestCameraPermission() else {
            await MainActor.run { self.lastError = "카메라 접근 권한이 필요합니다." }
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }
        session.commitConfiguration()
        session.startRunning()
    }

    private func requestCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default: return false
        }
    }

    // MARK: - Capture

    func capturePhoto() {
        guard captureState == .idle else { return }
        captureState = .capturing
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func stopSession() {
        Task.detached { [session] in session.stopRunning() }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewModel: AVCapturePhotoCaptureDelegate {

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor in self.captureState = .idle }
            return
        }

        Task { @MainActor in
            self.captureState = .extracting
            do {
                let result = try await self.extractor.extract(from: image)
                await self.onCapture?(result.image, result.scale)
            } catch {
                self.lastError = "피사체를 찾지 못했어요. 다시 시도해보세요."
            }
            self.captureState = .idle
        }
    }
}
