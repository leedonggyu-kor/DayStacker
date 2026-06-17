import SwiftUI
import AVFoundation

struct CameraView: View {

    @ObservedObject var cameraVM: CameraViewModel
    let onCapture: (UIImage, Double) async -> Void

    var body: some View {
        ZStack {
            CameraPreviewLayer(session: cameraVM.session)
                .ignoresSafeArea()

            // Shutter button + state overlay
            VStack {
                Spacer()

                if let err = cameraVM.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.5))
                        .clipShape(Capsule())
                        .transition(.opacity)
                }

                ShutterButton(state: cameraVM.captureState) {
                    cameraVM.capturePhoto()
                }
                .padding(.bottom, 48)
            }

            // Swipe hint
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("위로 스와이프 — 오늘")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.trailing, 16)
                        .padding(.bottom, 8)
                }
            }
        }
        .onAppear {
            cameraVM.configure(onCapture: onCapture)
        }
        .onDisappear {
            cameraVM.stopSession()
        }
    }
}

// MARK: - Camera preview (UIViewRepresentable)

struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - Shutter button

struct ShutterButton: View {
    let state: CameraViewModel.CaptureState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: 3)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(state == .idle ? .white : .white.opacity(0.4))
                    .frame(width: 60, height: 60)
                    .scaleEffect(state == .extracting ? 0.7 : 1.0)
                    .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true),
                               value: state == .extracting)
            }
        }
        .disabled(state != .idle)
    }
}
