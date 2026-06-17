import Foundation
import SwiftData

@Model
final class Day {
    @Attribute(.unique) var id: String  // "2026-06-17"
    @Relationship(deleteRule: .cascade) var objects: [CapturedObject]
    var isComplete: Bool

    init(id: String) {
        self.id = id
        self.objects = []
        self.isComplete = false
    }

    // Adjusted day ID: captures before 4 AM belong to the previous day
    static func dayID(for date: Date = .now) -> String {
        let adjusted = date.addingTimeInterval(-4 * 3600)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        return fmt.string(from: adjusted)
    }
}
