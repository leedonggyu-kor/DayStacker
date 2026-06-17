import SwiftUI
import SwiftData

@MainActor
final class CanvasViewModel: ObservableObject {

    @Published var todayDay: Day?
    @Published var isLoading = false

    private var modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadOrCreateToday()
    }

    // MARK: - Day management

    func loadOrCreateToday() {
        let todayID = Day.dayID()
        let descriptor = FetchDescriptor<Day>(
            predicate: #Predicate { $0.id == todayID }
        )

        do {
            let days = try modelContext.fetch(descriptor)
            if let existing = days.first {
                todayDay = existing
            } else {
                let newDay = Day(id: todayID)
                modelContext.insert(newDay)
                try modelContext.save()
                todayDay = newDay
            }
        } catch {
            print("CanvasViewModel: day load error \(error)")
        }

        markCompletedDays()
    }

    // Mark past days as complete
    private func markCompletedDays() {
        let todayID = Day.dayID()
        let descriptor = FetchDescriptor<Day>(
            predicate: #Predicate { !$0.isComplete && $0.id != todayID }
        )
        guard let past = try? modelContext.fetch(descriptor) else { return }
        for day in past {
            day.isComplete = true
        }
        try? modelContext.save()
    }

    // MARK: - Adding objects

    func addObject(image: UIImage, scale: Double) {
        guard let day = todayDay else { return }
        guard let pngData = image.pngData() else { return }

        let obj = CapturedObject(
            imageData: pngData,
            scale: scale
        )
        day.objects.append(obj)
        try? modelContext.save()
    }

    // MARK: - Updating settled positions

    func updatePositions(_ states: [ObjectState]) {
        guard let day = todayDay else { return }
        for state in states {
            if let obj = day.objects.first(where: { $0.id == state.id }) {
                obj.positionX = state.x
                obj.positionY = state.y
                obj.rotation = state.rotation
            }
        }
        try? modelContext.save()
    }

    // MARK: - Archive

    func fetchAllDays() -> [Day] {
        let descriptor = FetchDescriptor<Day>(
            sortBy: [SortDescriptor(\Day.id, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func day(for id: String) -> Day? {
        let descriptor = FetchDescriptor<Day>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }
}
