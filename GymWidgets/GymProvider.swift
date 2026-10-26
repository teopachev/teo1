import WidgetKit
import SwiftUI

struct GymEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Lee la foto que deja la app. No calcula nada: si no hay foto, enseña un
/// estado vacío en vez de inventarse datos.
struct GymProvider: TimelineProvider {
    func placeholder(in context: Context) -> GymEntry {
        GymEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (GymEntry) -> Void) {
        completion(GymEntry(date: .now, snapshot: context.isPreview ? .preview : WidgetStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GymEntry>) -> Void) {
        let entry = GymEntry(date: .now, snapshot: WidgetStore.load())
        // Se refresca al cambiar de día aunque no toques la app, para que el
        // widget no se quede colgado del día anterior.
        let midnight = Calendar.current.startOfDay(for: Date.now.addingTimeInterval(86_400))
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
}

extension WidgetSnapshot {
    /// Datos de mentira para la vista previa de la galería de widgets.
    static var preview: WidgetSnapshot {
        var s = WidgetSnapshot()
        s.sessionsThisWeek = 3
        s.weeklyGoal = 4
        s.streak = 5
        s.weekVolume = 8200
        s.totalSessions = 42
        s.hasRoutineToday = true
        s.todayRoutineName = "Empuje"
        s.todayRoutineSymbol = "figure.strengthtraining.traditional"
        s.todayRoutineColorHex = "6FA0C8"
        return s
    }
}
