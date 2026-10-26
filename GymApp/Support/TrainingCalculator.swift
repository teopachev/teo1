import Foundation

/// Cálculos del módulo de entrenamiento: 1RM estimado, volumen, marcas
/// personales y rachas. Todo se deriva de `WorkoutSession`, nunca de una
/// plantilla: las plantillas son intención, las sesiones son lo que pasó.
enum TrainingCalculator {

    /// 1RM estimado mediante la fórmula de Epley.
    /// Con 1 repetición devuelve el propio peso.
    static func oneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        guard reps > 1 else { return weight }
        return weight * (1 + Double(reps) / 30)
    }

    static func restLabel(_ seconds: Int) -> String { Fmt.restLabel(seconds) }

    // MARK: - Historial por ejercicio

    /// Todas las series registradas de un ejercicio, en todas las sesiones,
    /// ordenadas de más antigua a más reciente. Empareja por nombre además de
    /// por referencia: si el ejercicio del catálogo se borró, el historial
    /// sigue encontrándose por el nombre que quedó copiado en la sesión.
    static func history(of exercise: Exercise, in sessions: [WorkoutSession]) -> [(date: Date, set: LoggedSet)] {
        var result: [(date: Date, set: LoggedSet)] = []
        for session in sessions {
            for sessionExercise in session.exercises {
                let matches = sessionExercise.exercise?.persistentModelID == exercise.persistentModelID
                    || sessionExercise.exerciseName.folded == exercise.name.folded
                guard matches else { continue }
                for set in sessionExercise.sets where set.isCompleted {
                    result.append((session.date, set))
                }
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    struct PersonalRecords {
        var maxWeight: Double = 0
        var maxWeightReps: Int = 0
        var maxOneRepMax: Double = 0
        var maxVolumeInSession: Double = 0
        var bestSetDate: Date?
    }

    /// Mejores marcas históricas para un ejercicio, a partir de su historial.
    static func personalRecords(from history: [(date: Date, set: LoggedSet)]) -> PersonalRecords {
        var pr = PersonalRecords()
        var volumeByDay: [Date: Double] = [:]
        let calendar = Calendar.current

        for entry in history where !entry.set.isWarmup {
            let set = entry.set
            if set.weight > pr.maxWeight || (set.weight == pr.maxWeight && set.reps > pr.maxWeightReps) {
                pr.maxWeight = set.weight
                pr.maxWeightReps = set.reps
                pr.bestSetDate = entry.date
            }
            pr.maxOneRepMax = max(pr.maxOneRepMax, set.estimatedOneRepMax)
            let day = calendar.startOfDay(for: entry.date)
            volumeByDay[day, default: 0] += set.volume
        }
        pr.maxVolumeInSession = volumeByDay.values.max() ?? 0
        return pr
    }

    /// True si esta serie concreta iguala o mejora el mejor peso levantado
    /// hasta ANTES de que se registrara (para marcar "Nuevo PR" en el momento).
    static func isPersonalRecord(_ set: LoggedSet, priorHistory: [(date: Date, set: LoggedSet)]) -> Bool {
        guard !set.isWarmup, set.weight > 0 else { return false }
        let priorBest = priorHistory.filter { !$0.set.isWarmup }.map(\.set.weight).max() ?? 0
        return set.weight > priorBest
    }

    // MARK: - Estadísticas generales

    /// Volumen total movido en una ventana de fechas (por defecto, esta semana).
    static func volume(in sessions: [WorkoutSession], from start: Date, to end: Date = .now) -> Double {
        sessions
            .filter { $0.date >= start && $0.date <= end }
            .reduce(0) { $0 + $1.totalVolume }
    }

    /// Nº de semanas naturales consecutivas (terminando en la actual) con al
    /// menos un entrenamiento registrado.
    static func weekStreak(_ sessions: [WorkoutSession]) -> Int {
        guard !sessions.isEmpty else { return 0 }
        let calendar = Calendar.current
        var weeksWithSessions = Set<DateComponents>()
        for session in sessions {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date)
            weeksWithSessions.insert(comps)
        }
        var streak = 0
        var cursor = Date.now
        while true {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: cursor)
            guard weeksWithSessions.contains(comps) else { break }
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// Reparte el nº de series objetivo de una rutina por grupo muscular.
    static func setsByMuscle(in routine: Routine) -> [(group: MuscleGroup, sets: Int)] {
        var totals: [MuscleGroup: Int] = [:]
        for item in routine.exercises {
            guard let group = item.exercise?.muscleGroup else { continue }
            totals[group, default: 0] += item.sets.count
        }
        return totals
            .map { (group: $0.key, sets: $0.value) }
            .sorted { $0.sets > $1.sets }
    }

    // MARK: - Progreso general

    /// Series de trabajo realmente hechas por grupo muscular en una ventana
    /// de tiempo, a partir de las sesiones reales (no de plantillas).
    static func setsByMuscle(in sessions: [WorkoutSession], since start: Date) -> [(group: MuscleGroup, sets: Int)] {
        var totals: [MuscleGroup: Int] = [:]
        for session in sessions where session.date >= start {
            for item in session.exercises {
                guard let group = item.exercise?.muscleGroup else { continue }
                totals[group, default: 0] += item.sets.filter { $0.isCompleted && !$0.isWarmup }.count
            }
        }
        return totals
            .map { (group: $0.key, sets: $0.value) }
            .sorted { $0.sets > $1.sets }
    }

    /// Volumen total por semana natural, de más antigua a más reciente.
    /// Las semanas sin entreno aparecen igualmente, con volumen 0.
    static func weeklyVolume(_ sessions: [WorkoutSession], weeks: Int) -> [(weekStart: Date, volume: Double)] {
        let calendar = Calendar.current
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        var result: [(weekStart: Date, volume: Double)] = []
        for offset in stride(from: weeks - 1, through: 0, by: -1) {
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { continue }
            let volume = sessions
                .filter { $0.date >= start && $0.date < end }
                .reduce(0) { $0 + $1.totalVolume }
            result.append((weekStart: start, volume: volume))
        }
        return result
    }

    struct RecentRecord {
        var exercise: Exercise
        var weight: Double
        var reps: Int
        var date: Date
    }

    /// Marcas personales conseguidas dentro de los últimos `days` días, para
    /// enseñar un resumen de "esto has batido hace poco" en Progreso.
    static func recentPersonalRecords(exercises: [Exercise], sessions: [WorkoutSession], withinDays days: Int) -> [RecentRecord] {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) else { return [] }
        var result: [RecentRecord] = []
        for exercise in exercises {
            let full = history(of: exercise, in: sessions)
            let records = personalRecords(from: full)
            guard let date = records.bestSetDate, date >= cutoff, records.maxWeight > 0 else { continue }
            result.append(RecentRecord(exercise: exercise, weight: records.maxWeight, reps: records.maxWeightReps, date: date))
        }
        return result.sorted { $0.date > $1.date }
    }
}

extension String {
    /// Nombre normalizado (minúsculas, sin tildes) para comparar sin
    /// depender de mayúsculas o acentos exactos.
    var folded: String {
        folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }
}
