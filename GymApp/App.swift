import SwiftUI
import SwiftData

@main
struct GymAppApp: App {
    let modelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self, Routine.self, RoutineExercise.self, RoutineSet.self,
            WorkoutSession.self, SessionExercise.self, LoggedSet.self, BodyWeightEntry.self
        ])
        let config = ModelConfiguration(schema: schema)
        return (try? ModelContainer(for: schema, configurations: [config]))
            ?? (try! ModelContainer(for: schema))
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                // App monocroma oscura por diseño: no sigue el modo claro del
                // sistema, igual que Fotos o Apple TV.
                .preferredColorScheme(.dark)
                .tint(Palette.accent)
        }
        .modelContainer(modelContainer)
    }
}
