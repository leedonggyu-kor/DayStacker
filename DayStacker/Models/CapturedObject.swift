import Foundation
import SwiftData

@Model
final class CapturedObject {
    var id: UUID
    // Transparent-background PNG with white border already composited
    var imageData: Data
    // Most recently settled physics state (updated each time new object drops)
    var positionX: Double
    var positionY: Double
    var rotation: Double  // radians
    // Fraction of canvas width the subject occupied in the original photo
    var scale: Double
    var capturedAt: Date

    init(
        id: UUID = UUID(),
        imageData: Data,
        positionX: Double = 0,
        positionY: Double = 0,
        rotation: Double = 0,
        scale: Double = 1,
        capturedAt: Date = .now
    ) {
        self.id = id
        self.imageData = imageData
        self.positionX = positionX
        self.positionY = positionY
        self.rotation = rotation
        self.scale = scale
        self.capturedAt = capturedAt
    }
}
