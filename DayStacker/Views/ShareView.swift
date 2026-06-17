import SwiftUI
import SpriteKit

struct ShareView: View {

    let scene: CanvasScene
    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: UIImage?
    @State private var isRendering = true
    @State private var showActivitySheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.1).ignoresSafeArea()

                if isRendering {
                    ProgressView("렌더링 중…")
                        .tint(.white)
                } else if let img = renderedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(24)
                        .transition(.opacity)
                }
            }
            .navigationTitle("내보내기")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showActivitySheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(renderedImage == nil)
                }
            }
            .sheet(isPresented: $showActivitySheet) {
                if let img = renderedImage {
                    ActivitySheet(activityItems: [img])
                }
            }
        }
        .task { await render() }
    }

    @MainActor
    private func render() async {
        // Snapshot the live SpriteKit view that is presenting this scene
        guard let view = scene.view else {
            isRendering = false
            return
        }
        let size = view.bounds.size
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: false)
        }
        renderedImage = img
        isRendering = false
    }
}

// MARK: - UIActivityViewController wrapper

struct ActivitySheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
