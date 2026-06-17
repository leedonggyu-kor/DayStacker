import SwiftUI
import SwiftData

@main
struct DayStackerApp: App {

    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Day.self, CapturedObject.self)
        } catch {
            fatalError("SwiftData container 생성 실패: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(modelContext: container.mainContext)
        }
        .modelContainer(container)
    }
}
