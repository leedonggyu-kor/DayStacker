import SwiftUI
import SpriteKit

struct CanvasView: View {

    @ObservedObject var canvasVM: CanvasViewModel
    let pendingObject: (image: UIImage, scale: Double)?
    let onObjectAdded: () -> Void

    @State private var scene: CanvasScene?

    var body: some View {
        ZStack {
            Color(white: 0.97).ignoresSafeArea()

            if let scene {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .ignoresSafeArea()
            }
        }
        .onAppear(perform: setupScene)
        .onChange(of: pendingObject?.image) { newImage in
            guard let image = newImage, let scale = pendingObject?.scale else { return }
            canvasVM.addObject(image: image, scale: scale)
            if let newObj = canvasVM.todayDay?.objects.last {
                scene?.addObject(id: newObj.id, image: image, scale: scale)
            }
            onObjectAdded()
        }
    }

    private func setupScene() {
        guard scene == nil else { return }
        let size = UIScreen.main.bounds.size
        let newScene = CanvasScene(size: size)
        newScene.scaleMode = .resizeFill
        newScene.canvasDelegate = CanvasSettleHandler(vm: canvasVM)

        // Restore all saved objects
        if let day = canvasVM.todayDay {
            let snapshots = day.objects.compactMap { obj -> (id: UUID, image: UIImage, scale: Double, x: Double, y: Double, rotation: Double)? in
                guard let img = UIImage(data: obj.imageData) else { return nil }
                return (obj.id, img, obj.scale, obj.positionX, obj.positionY, obj.rotation)
            }
            if day.isComplete {
                newScene.loadStaticObjects(snapshots: snapshots)
            } else {
                for snap in snapshots {
                    newScene.addObject(id: snap.id, image: snap.image, scale: snap.scale,
                                       existingX: snap.x, existingY: snap.y, existingRotation: snap.rotation)
                }
            }
        }

        scene = newScene
    }
}

// MARK: - Settle delegate bridging to async SwiftData

private final class CanvasSettleHandler: NSObject, CanvasSceneDelegate {
    private weak var vm: CanvasViewModel?

    init(vm: CanvasViewModel) { self.vm = vm }

    func canvasScene(_ scene: CanvasScene, didSettleWithStates states: [ObjectState]) {
        Task { @MainActor [weak vm] in
            vm?.updatePositions(states)
        }
    }
}
