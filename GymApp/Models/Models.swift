import Foundation
import SwiftData

// MARK: - Ejercicio (catálogo)

/// Un ejercicio del catálogo. Es reutilizable en cualquier rutina y en
/// cualquier sesión: el historial de progreso se agrupa por este ejercicio.
@Model
final class Exercise {
    var name: String
    var muscleGroup: MuscleGroup
    var equipment: Equipment
    var notes: String
    var isFavorite: Bool
    var createdAt: Date

    init(
        name: String,
        muscleGroup: MuscleGroup,
        equipment: Equipment = .barbell,
        notes: String = "",
        isFavorite: Bool = false,
        createdAt: Date = .now
    ) {
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.notes = notes
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }

    var symbol: String { equipment.symbol }
    var colorHex: String { muscleGroup.colorHex }
}

// MARK: - Rutina (plantilla)

/// Una plantilla de entrenamiento (p. ej. "Empuje", "Pierna"). Define qué
/// ejercicios y series objetivo tiene, y en qué días se programa. No guarda
/// ningún resultado real: eso vive en `WorkoutSession`.
@Model
final class Routine {
    var name: String
    var detail: String
    var colorHex: String
    var symbol: String
    /// Días de la semana programados (lunes = 1 ... domingo = 7).
    var scheduledDays: [Int]
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var exercises: [RoutineExercise]

    init(
        name: String,
        detail: String = "",
        colorHex: String = "6FA0C8",
        symbol: String = "figure.strengthtraining.traditional",
        scheduledDays: [Int] = [],
        createdAt: Date = .now,
        exercises: [RoutineExercise] = []
    ) {
        self.name = name
        self.detail = detail
        self.colorHex = colorHex
        self.symbol = symbol
        self.scheduledDays = scheduledDays
        self.createdAt = createdAt
        self.exercises = exercises
    }

    var orderedExercises: [RoutineExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var muscleGroups: [MuscleGroup] {
        var seen: [MuscleGroup] = []
        for item in orderedExercises {
            if let group = item.exercise?.muscleGroup, !seen.contains(group) {
                seen.append(group)
            }
        }
        return seen
    }

    var scheduledWeekdays: [Weekday] {
        scheduledDays.compactMap { Weekday(rawValue: $0) }.sorted { $0.rawValue < $1.rawValue }
    }

    /// Duración estimada en minutos (heurística: series × 3 min, contando descansos).
    var estimatedMinutes: Int {
        Int((Double(totalSets) * 3).rounded())
    }
}

// MARK: - Ejercicio dentro de una rutina

@Model
final class RoutineExercise {
    var order: Int
    var restSeconds: Int
    var notes: String

    var routine: Routine?

    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \RoutineSet.routineExercise)
    var sets: [RoutineSet]

    init(
        order: Int = 0,
        restSeconds: Int = 90,
        notes: String = "",
        exercise: Exercise? = nil,
        sets: [RoutineSet] = []
    ) {
        self.order = order
        self.restSeconds = restSeconds
        self.notes = notes
        self.exercise = exercise
        self.sets = sets
    }

    var orderedSets: [RoutineSet] {
        sets.sorted { $0.order < $1.order }
    }

    /// Resumen tipo "4 × 8" (series de trabajo × reps de la primera).
    var schemeSummary: String {
        let working = orderedSets.filter { !$0.isWarmup }
        guard let reps = working.first?.targetReps, !working.isEmpty else {
            return "\(sets.count) series"
        }
        return "\(working.count) × \(reps)"
    }
}

// MARK: - Serie objetivo (plantilla)

@Model
final class RoutineSet {
    var order: Int
    var targetReps: Int
    var targetWeight: Double
    var isWarmup: Bool

    var routineExercise: RoutineExercise?

    init(order: Int = 0, targetReps: Int = 8, targetWeight: Double = 0, isWarmup: Bool = false) {
        self.order = order
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.isWarmup = isWarmup
    }

    var isBodyweight: Bool { routineExercise?.exercise?.equipment == .bodyweight }

    var loadText: String? {
        if isBodyweight {
            return targetWeight > 0 ? "+\(Fmt.weight(targetWeight))" : "Peso corporal"
        }
        return targetWeight > 0 ? Fmt.weight(targetWeight) : nil
    }
}

// MARK: - Sesión de entrenamiento (historial real)

/// Un entrenamiento realizado de verdad, con fecha, duración y cada serie tal
/// y como se hizo. Es la fuente de todo el progreso: nunca se sobrescribe,
/// solo se añade. Puede venir de una rutina o ser libre (sin plantilla).
@Model
final class WorkoutSession {
    var date: Date
    var durationSeconds: Int
    var notes: String
    var routineName: String
    var routineColorHex: String
    var routineSymbol: String

    @Relationship(deleteRule: .nullify)
    var routine: Routine?

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise]

    init(
        date: Date = .now,
        durationSeconds: Int = 0,
        notes: String = "",
        routineName: String = "Entreno libre",
        routineColorHex: String = "6FA0C8",
        routineSymbol: String = "bolt.fill",
        routine: Routine? = nil,
        exercises: [SessionExercise] = []
    ) {
        self.date = date
        self.durationSeconds = durationSeconds
        self.notes = notes
        self.routineName = routineName
        self.routineColorHex = routineColorHex
        self.routineSymbol = routineSymbol
        self.routine = routine
        self.exercises = exercises
    }

    var orderedExercises: [SessionExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    /// Todas las series confirmadas (con reps y peso reales) de la sesión.
    var completedSets: [LoggedSet] {
        exercises.flatMap(\.sets).filter(\.isCompleted)
    }

    var totalSets: Int { completedSets.count }

    var totalVolume: Double {
        completedSets.reduce(0) { $0 + $1.volume }
    }
}

// MARK: - Ejercicio dentro de una sesión

@Model
final class SessionExercise {
    var order: Int
    var restSeconds: Int
    var notes: String
    /// Copia del nombre en el momento de entrenar: si borras el ejercicio del
    /// catálogo más tarde, el historial sigue siendo legible.
    var exerciseName: String
    var exerciseColorHex: String
    var exerciseSymbol: String

    var session: WorkoutSession?

    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.sessionExercise)
    var sets: [LoggedSet]

    init(
        order: Int = 0,
        restSeconds: Int = 90,
        notes: String = "",
        exerciseName: String = "",
        exerciseColorHex: String = "9C9CA6",
        exerciseSymbol: String = "dumbbell.fill",
        exercise: Exercise? = nil,
        sets: [LoggedSet] = []
    ) {
        self.order = order
        self.restSeconds = restSeconds
        self.notes = notes
        self.exerciseName = exerciseName
        self.exerciseColorHex = exerciseColorHex
        self.exerciseSymbol = exerciseSymbol
        self.exercise = exercise
        self.sets = sets
    }

    var orderedSets: [LoggedSet] {
        sets.sorted { $0.order < $1.order }
    }

    var volume: Double {
        sets.filter(\.isCompleted).reduce(0) { $0 + $1.volume }
    }

    /// La mejor serie de trabajo confirmada (más peso; a igual peso, más reps).
    var topSet: LoggedSet? {
        sets.filter { $0.isCompleted && !$0.isWarmup }
            .max { ($0.weight, $0.reps) < ($1.weight, $1.reps) }
    }
}

// MARK: - Serie registrada (el dato real)

/// Una serie tal y como se hizo de verdad: reps y peso levantado. Esto es lo
/// que alimenta el 1RM estimado, el volumen y las marcas personales.
@Model
final class LoggedSet {
    var order: Int
    var reps: Int
    var weight: Double
    var isWarmup: Bool
    /// True cuando se ha confirmado la serie de verdad en directo. Antes de
    /// eso, `reps`/`weight` solo son la sugerencia editable, no un hecho.
    var isCompleted: Bool
    var completedAt: Date

    var sessionExercise: SessionExercise?

    init(
        order: Int = 0,
        reps: Int = 0,
        weight: Double = 0,
        isWarmup: Bool = false,
        isCompleted: Bool = false,
        completedAt: Date = .now
    ) {
        self.order = order
        self.reps = reps
        self.weight = weight
        self.isWarmup = isWarmup
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }

    /// Volumen de la serie confirmada (reps × peso). Las series de
    /// calentamiento y las no confirmadas no suman.
    var volume: Double {
        (isWarmup || !isCompleted) ? 0 : Double(reps) * weight
    }

    var estimatedOneRepMax: Double {
        TrainingCalculator.oneRepMax(weight: weight, reps: reps)
    }

    var isBodyweight: Bool { sessionExercise?.exercise?.equipment == .bodyweight }

    var loadText: String {
        if isBodyweight {
            return weight > 0 ? "+\(Fmt.weight(weight))" : "Peso corporal"
        }
        return Fmt.weight(weight)
    }
}

// MARK: - Peso corporal

/// Un pesaje. Independiente de las sesiones: te puedes pesar cualquier día,
/// entrenes o no. Sirve para ver la evolución junto al progreso de fuerza.
@Model
final class BodyWeightEntry {
    var date: Date
    var kg: Double

    init(date: Date = .now, kg: Double) {
        self.date = date
        self.kg = kg
    }
}
