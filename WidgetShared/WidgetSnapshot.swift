import Foundation

/// La foto que la app le deja al widget. El widget no lee SwiftData
/// directamente (compartir el almacén entre procesos es delicado); en vez de
/// eso, la app escribe esta foto cada vez que cambia algo relevante y el
/// widget solo la lee. Es de solo lectura y pesa nada.
struct WidgetSnapshot: Codable, Equatable {
    var updatedAt: Date = .now

    var sessionsThisWeek: Int = 0
    var weeklyGoal: Int = 4
    var streak: Int = 0
    var weekVolume: Double = 0
    var totalSessions: Int = 0

    var hasRoutineToday: Bool = false
    var todayRoutineName: String = ""
    var todayRoutineSymbol: String = "dumbbell.fill"
    var todayRoutineColorHex: String = "6FA0C8"

    var didTrainToday: Bool = false
    var lastSessionName: String = ""
    var lastSessionDate: Date?

    var progress: Double { weeklyGoal > 0 ? Double(sessionsThisWeek) / Double(weeklyGoal) : 0 }
}

/// Dónde se guarda la foto: los ajustes compartidos del App Group, el único
/// sitio al que llegan a la vez la app y su extensión de widgets.
enum WidgetStore {
    static let appGroup = "group.com.teodorpachev.GymApp"
    private static let key = "widgetSnapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    /// Si la foto es de una versión anterior le faltarán campos y no
    /// descodificará; se devuelve una vacía y la app la vuelve a escribir en
    /// cuanto se abra.
    static func load() -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }
}

/// Colores para el widget, repetidos a propósito del tema de la app: una
/// extensión no puede ver la carpeta de diseño sin arrastrarla entera, y debe
/// pesar lo mínimo.
enum WidgetPalette {
    static let canvasHex      = "0A0A0C"
    static let textPrimaryHex = "F2F2F5"
    static let textDimHex     = "9D9DA6"
    static let textFaintHex   = "66666E"
    static let accentHex      = "6FA0C8"
    static let recordHex      = "E3B34D"
}
