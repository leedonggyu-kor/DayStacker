import SwiftUI
import SwiftData

struct ContentView: View {

    @StateObject private var cameraVM = CameraViewModel()
    @StateObject private var canvasVM: CanvasViewModel

    @State private var verticalOffset: CGFloat = 0
    @State private var showArchive = false
    @State private var pendingObject: (image: UIImage, scale: Double)?
    @State private var screenHeight: CGFloat = UIScreen.main.bounds.height

    init(modelContext: ModelContext) {
        _canvasVM = StateObject(wrappedValue: CanvasViewModel(modelContext: modelContext))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {

                // Layer 0: Camera
                CameraView(cameraVM: cameraVM) { image, scale in
                    pendingObject = (image, scale)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        verticalOffset = -geo.size.height
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .offset(y: verticalOffset)

                // Layer 1: Canvas
                CanvasView(
                    canvasVM: canvasVM,
                    pendingObject: pendingObject,
                    onObjectAdded: { pendingObject = nil }
                )
                .frame(width: geo.size.width, height: geo.size.height)
                .offset(y: geo.size.height + verticalOffset)

                // Archive button — always visible
                HStack {
                    Spacer()
                    Button { showArchive = true } label: {
                        Image(systemName: "square.stack.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 18)
                    .padding(.top, geo.safeAreaInsets.top + 12)
                }
                .offset(y: verticalOffset)
            }
            .gesture(verticalDragGesture(geo: geo))
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showArchive) {
            ArchiveView(canvasVM: canvasVM)
        }
    }

    private func verticalDragGesture(geo: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = verticalOffset + value.translation.height
                verticalOffset = max(-geo.size.height, min(0, proposed))
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.height
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    if velocity < -150 || verticalOffset < -geo.size.height * 0.4 {
                        verticalOffset = -geo.size.height
                    } else {
                        verticalOffset = 0
                    }
                }
            }
    }
}
