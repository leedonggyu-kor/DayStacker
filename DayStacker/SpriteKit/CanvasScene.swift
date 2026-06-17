import SpriteKit
import UIKit

protocol CanvasSceneDelegate: AnyObject {
    func canvasScene(_ scene: CanvasScene, didSettleWithStates states: [ObjectState])
}

struct ObjectState {
    let id: UUID
    let x: Double
    let y: Double
    let rotation: Double
}

final class CanvasScene: SKScene, SKPhysicsContactDelegate {

    weak var canvasDelegate: CanvasSceneDelegate?

    private var objectNodes: [UUID: SKSpriteNode] = [:]
    private var cameraNode = SKCameraNode()

    // Physics wall nodes — repositioned as scene grows
    private var leftWall = SKNode()
    private var rightWall = SKNode()
    private var floor = SKNode()

    private var sceneContentWidth: CGFloat = 390
    private var sceneContentHeight: CGFloat = 2000

    private var settleTimer: TimeInterval = 0
    private var isSettled = false
    private var pendingSettle = false

    private let settleDuration: TimeInterval = 0.8
    private let velocityThreshold: CGFloat = 5.0

    // MARK: - Setup

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(white: 0.97, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: -600)
        physicsWorld.contactDelegate = self

        setupCamera()
        setupWalls()
    }

    private func setupCamera() {
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = CGPoint(x: 0, y: frame.height * 0.4)
    }

    private func setupWalls() {
        buildStaticBody(node: floor,
                        size: CGSize(width: sceneContentWidth + 400, height: 20),
                        position: CGPoint(x: 0, y: 0))
        buildStaticBody(node: leftWall,
                        size: CGSize(width: 20, height: sceneContentHeight * 2),
                        position: CGPoint(x: -sceneContentWidth / 2, y: sceneContentHeight))
        buildStaticBody(node: rightWall,
                        size: CGSize(width: 20, height: sceneContentHeight * 2),
                        position: CGPoint(x: sceneContentWidth / 2, y: sceneContentHeight))
        addChild(floor); addChild(leftWall); addChild(rightWall)
    }

    private func buildStaticBody(node: SKNode, size: CGSize, position: CGPoint) {
        node.position = position
        node.physicsBody = SKPhysicsBody(rectangleOf: size)
        node.physicsBody?.isDynamic = false
        node.physicsBody?.friction = 0.7
        node.physicsBody?.restitution = 0.05
    }

    // MARK: - Public API

    func addObject(id: UUID, image: UIImage, scale: Double, existingX: Double? = nil, existingY: Double? = nil, existingRotation: Double? = nil) {
        let texture = SKTexture(image: image)
        let nodeWidth = sceneContentWidth * CGFloat(scale)
        let aspectRatio = image.size.height / image.size.width
        let nodeSize = CGSize(width: nodeWidth, height: nodeWidth * aspectRatio)

        let node = SKSpriteNode(texture: texture, size: nodeSize)

        if let x = existingX, let y = existingY {
            // Restore from saved state (completed day — static)
            node.position = CGPoint(x: x, y: y)
            node.zRotation = existingRotation ?? 0
        } else {
            // Drop from top with slight horizontal spread
            let dropX = CGFloat.random(in: -sceneContentWidth * 0.3 ... sceneContentWidth * 0.3)
            let topY = topOfContent() + nodeSize.height + 80
            node.position = CGPoint(x: dropX, y: topY)
            node.zRotation = CGFloat.random(in: -0.15 ... 0.15)
            node.physicsBody = makePhysicsBody(texture: texture, size: nodeSize)
            // Slight initial horizontal velocity for natural feel
            node.physicsBody?.velocity = CGVector(dx: CGFloat.random(in: -30...30), dy: -50)
            node.physicsBody?.angularVelocity = CGFloat.random(in: -0.5...0.5)
        }

        objectNodes[id] = node
        addChild(node)

        pendingSettle = true
        isSettled = false
        settleTimer = 0
    }

    func loadStaticObjects(snapshots: [(id: UUID, image: UIImage, scale: Double, x: Double, y: Double, rotation: Double)]) {
        for snap in snapshots {
            addObject(id: snap.id, image: snap.image, scale: snap.scale,
                      existingX: snap.x, existingY: snap.y, existingRotation: snap.rotation)
        }
        adjustCamera(animated: false)
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        guard pendingSettle else { return }

        let allResting = objectNodes.values.allSatisfy { node in
            guard let body = node.physicsBody, body.isDynamic else { return true }
            return body.velocity.magnitude < velocityThreshold &&
                   abs(body.angularVelocity) < 0.05
        }

        if allResting {
            settleTimer += 1.0 / 60.0
            if settleTimer >= settleDuration {
                onSettled()
            }
        } else {
            settleTimer = 0
        }

        adjustCamera(animated: true)
    }

    private func onSettled() {
        guard pendingSettle else { return }
        pendingSettle = false
        isSettled = true

        let states = objectNodes.compactMap { (id, node) -> ObjectState? in
            ObjectState(id: id, x: Double(node.position.x),
                        y: Double(node.position.y), rotation: Double(node.zRotation))
        }
        canvasDelegate?.canvasScene(self, didSettleWithStates: states)
    }

    // MARK: - Camera / Viewport

    private func adjustCamera(animated: Bool) {
        let top = topOfContent()
        let contentHeight = max(top + 80, frame.height)
        let viewportHeight = frame.height

        let targetScale = max(1.0, contentHeight / viewportHeight * 1.05)
        let targetY = contentHeight / 2

        if animated {
            let scaleAction = SKAction.customAction(withDuration: 0.4) { [weak self] _, t in
                guard let self else { return }
                self.cameraNode.xScale += (targetScale - self.cameraNode.xScale) * 0.05
                self.cameraNode.yScale = self.cameraNode.xScale
                self.cameraNode.position.y += (targetY - self.cameraNode.position.y) * 0.05
            }
            cameraNode.run(SKAction.repeatForever(scaleAction), withKey: "cameraAdjust")
        } else {
            cameraNode.xScale = targetScale
            cameraNode.yScale = targetScale
            cameraNode.position.y = targetY
        }
    }

    private func topOfContent() -> CGFloat {
        objectNodes.values.map { $0.position.y + $0.size.height / 2 }.max() ?? frame.height * 0.5
    }

    // MARK: - Physics body

    private func makePhysicsBody(texture: SKTexture, size: CGSize) -> SKPhysicsBody {
        let body = SKPhysicsBody(texture: texture, size: size)
        body.isDynamic = true
        body.friction = 0.7
        body.restitution = 0.1
        body.linearDamping = 0.3
        body.angularDamping = 0.5
        body.mass = Float(size.width * size.height) * 0.0001
        return body
    }
}

// MARK: - Convenience

private extension CGVector {
    var magnitude: CGFloat { sqrt(dx*dx + dy*dy) }
}
