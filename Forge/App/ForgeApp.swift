import SwiftUI
import SwiftData

@main
struct ForgeApp: App {
    private let modelContainer: ModelContainer
    let sessionEngine: SessionEngine

    init() {
        do {
            modelContainer = try ModelContainerFactory.makeSharedContainer()
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
        sessionEngine = SessionEngine.make(modelContainer: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
        }
    }
}
