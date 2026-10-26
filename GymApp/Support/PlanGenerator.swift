import Foundation

/// Genera un plan de rutinas a partir de un objetivo, una familia de split y
/// cuántos días de cada tipo quieres, tirando de ejercicios ya existentes en
/// el catálogo. No toca SwiftData: produce una estructura de valor que la
/// pantalla de previsualización enseña y, si se confirma, materializa en
/// `Routine`/`RoutineExercise`/`RoutineSet` reales.
enum PlanGenerator {

    // MARK: - Tipos de día y familias de split

    enum DayKind: String, CaseIterable, Identifiable, Hashable {
        case fullBody, torso, pierna, empuje, tiron

        var id: String { rawValue }

        var title: String {
            switch self {
            case .fullBody: return "Cuerpo completo"
            case .torso:    return "Torso"
            case .pierna:   return "Pierna"
            case .empuje:   return "Empuje"
            case .tiron:    return "Tirón"
            }
        }
    }

    enum SplitFamily: String, CaseIterable, Identifiable, Hashable {
        case fullBody, upperLower, pushPullLegs

        var id: String { rawValue }

        var title: String {
            switch self {
            case .fullBody:     return "Cuerpo completo"
            case .upperLower:   return "Torso / Pierna"
            case .pushPullLegs: return "Empuje / Tirón / Pierna"
            }
        }

        var detail: String {
            switch self {
            case .fullBody:     return "Cada sesión toca todos los grupos musculares"
            case .upperLower:   return "Divides tren superior e inferior"
            case .pushPullLegs: return "Divides por tipo de movimiento"
            }
        }

        var symbol: String {
            switch self {
            case .fullBody:     return "figure.mixed.cardio"
            case .upperLower:   return "figure.arms.open"
            case .pushPullLegs: return "arrow.triangle.branch"
            }
        }

        /// Los tipos de día que componen esta familia, en el orden en que se
        /// reparten cuando se generan los días de la semana.
        var kinds: [DayKind] {
            switch self {
            case .fullBody:     return [.fullBody]
            case .upperLower:   return [.torso, .pierna]
            case .pushPullLegs: return [.empuje, .tiron, .pierna]
            }
        }

        /// Reparto por defecto para un nº de días dado: lo más equilibrado
        /// posible entre los tipos de la familia.
        func defaultComposition(days: Int) -> [DayKind: Int] {
            var result = Dictionary(uniqueKeysWithValues: kinds.map { ($0, 0) })
            guard !kinds.isEmpty else { return result }
            for i in 0..<max(0, days) {
                result[kinds[i % kinds.count], default: 0] += 1
            }
            return result
        }
    }

    struct GeneratedExercise: Identifiable {
        let id = UUID()
        let exercise: Exercise
        let sets: Int
        let reps: Int
        let restSeconds: Int
        let note: String
    }

    struct GeneratedDay: Identifiable {
        let id = UUID()
        let name: String
        let detail: String
        let symbol: String
        let colorHex: String
        var exercises: [GeneratedExercise]
        var scheduledDays: [Int] = []

        var totalSets: Int { exercises.reduce(0) { $0 + $1.sets } }
    }

    struct GeneratedPlan {
        let goal: TrainingGoal
        var days: [GeneratedDay]
    }

    // MARK: - Entrada principal

    static func generate(
        goal: TrainingGoal,
        daysPerWeek: Int,
        family: SplitFamily,
        composition: [DayKind: Int],
        level: ExperienceLevel,
        catalog: [Exercise],
        seed: Int = 0
    ) -> GeneratedPlan {
        var days = goal == .cardio
            ? cardioDays(count: daysPerWeek, catalog: catalog, seed: seed)
            : trainingDays(goal: goal, level: level, catalog: catalog, seed: seed, family: family, composition: composition)

        let weekdays = weekdayPattern(for: days.count)
        for index in days.indices {
            if index < weekdays.count {
                days[index].scheduledDays = [weekdays[index]]
            }
        }
        return GeneratedPlan(goal: goal, days: days)
    }

    private static func weekdayPattern(for count: Int) -> [Int] {
        switch count {
        case ...1: return [1]
        case 2:    return [1, 4]
        case 3:    return [1, 3, 5]
        case 4:    return [1, 2, 4, 5]
        case 5:    return [1, 2, 3, 4, 5]
        default:   return [1, 2, 3, 4, 5, 6]
        }
    }

    // MARK: - Días de fuerza / volumen / definición

    private struct SplitTemplate {
        let name: String
        let detail: String
        let symbol: String
        let colorHex: String
        /// Grupo, nº de ejercicios a coger de ese grupo, y filtro opcional de
        /// nombre (para separar bíceps/tríceps dentro de "Brazos").
        let slots: [(group: MuscleGroup, count: Int, filter: ((String) -> Bool)?)]
        let rankOffset: Int
    }

    /// Ordena los días respetando el reparto elegido, alternando tipos en vez
    /// de agruparlos (Torso, Pierna, Torso, Pierna en lugar de Torso, Torso,
    /// Pierna, Pierna), para no repetir el mismo grupo muscular dos días
    /// seguidos cuando se programan en días consecutivos de la semana.
    private static func orderedKinds(family: SplitFamily, composition: [DayKind: Int]) -> [DayKind] {
        var remaining = composition
        let total = composition.values.reduce(0, +)
        var sequence: [DayKind] = []
        var i = 0
        while sequence.count < total, i < total * family.kinds.count + 1 {
            let kind = family.kinds[i % family.kinds.count]
            if let left = remaining[kind], left > 0 {
                sequence.append(kind)
                remaining[kind] = left - 1
            }
            i += 1
        }
        return sequence
    }

    private static func trainingDays(goal: TrainingGoal, level: ExperienceLevel, catalog: [Exercise], seed: Int, family: SplitFamily, composition: [DayKind: Int]) -> [GeneratedDay] {
        let sequence = orderedKinds(family: family, composition: composition)
        let totalsByKind = composition
        var seenByKind: [DayKind: Int] = [:]
        var result: [GeneratedDay] = []
        for kind in sequence {
            let index = seenByKind[kind, default: 0]
            seenByKind[kind] = index + 1
            let showsSuffix = (totalsByKind[kind] ?? 1) > 1
            let suffix = showsSuffix ? String(UnicodeScalar(65 + index)!) : ""
            let template = template(for: kind, suffix: suffix, offset: index)
            result.append(buildDay(template, goal: goal, level: level, catalog: catalog, seed: seed))
        }
        return result
    }

    private static func template(for kind: DayKind, suffix: String, offset: Int) -> SplitTemplate {
        let name = suffix.isEmpty ? kind.title : "\(kind.title) \(suffix)"
        switch kind {
        case .fullBody:
            return SplitTemplate(name: name, detail: "Todo el cuerpo en una sesión",
                                  symbol: "figure.mixed.cardio", colorHex: "6FA0C8",
                                  slots: [(.chest, 1, nil), (.back, 1, nil), (.legs, 1, nil), (.shoulders, 1, nil), (.core, 1, nil)],
                                  rankOffset: offset)
        case .torso:
            return SplitTemplate(name: name, detail: "Pecho, espalda, hombro y brazo",
                                  symbol: "figure.arms.open", colorHex: "8A8FC8",
                                  slots: [(.chest, 1, nil), (.back, 1, nil), (.shoulders, 1, nil), (.arms, 2, nil)],
                                  rankOffset: offset)
        case .pierna:
            return SplitTemplate(name: name, detail: "Cuádriceps, isquios y glúteo",
                                  symbol: "figure.strengthtraining.traditional", colorHex: "6FC8A0",
                                  slots: [(.legs, 2, nil), (.glutes, 1, nil), (.core, 1, nil)],
                                  rankOffset: offset)
        case .empuje:
            return SplitTemplate(name: name, detail: "Pecho, hombro y tríceps",
                                  symbol: "arrow.up.right", colorHex: "C88A8A",
                                  slots: [(.chest, 2, nil), (.shoulders, 1, nil), (.arms, 1, isTriceps)],
                                  rankOffset: offset)
        case .tiron:
            return SplitTemplate(name: name, detail: "Espalda y bíceps",
                                  symbol: "arrow.down.left", colorHex: "6FA0C8",
                                  slots: [(.back, 2, nil), (.arms, 1, isBiceps)],
                                  rankOffset: offset)
        }
    }

    private static func buildDay(_ template: SplitTemplate, goal: TrainingGoal, level: ExperienceLevel, catalog: [Exercise], seed: Int) -> GeneratedDay {
        let scheme = repScheme(for: goal)
        let offset = template.rankOffset + seed
        var exercises: [GeneratedExercise] = []
        for slot in template.slots {
            let picked = pick(from: catalog, group: slot.group, count: slot.count, offset: offset, nameFilter: slot.filter)
            for exercise in picked {
                let sets = max(2, Int((Double(scheme.sets) * level.volumeMultiplier).rounded()))
                exercises.append(GeneratedExercise(exercise: exercise, sets: sets, reps: scheme.reps, restSeconds: scheme.rest, note: ""))
            }
        }
        if goal == .cutting, let finisher = pick(from: catalog, group: .cardio, count: 1, offset: offset, nameFilter: nil).first {
            exercises.append(GeneratedExercise(exercise: finisher, sets: 1, reps: 1, restSeconds: 0,
                                                note: "Remate: 12-15 min a ritmo constante, al terminar la fuerza."))
        }
        return GeneratedDay(name: template.name, detail: template.detail, symbol: template.symbol,
                             colorHex: template.colorHex, exercises: exercises)
    }

    private static func repScheme(for goal: TrainingGoal) -> (sets: Int, reps: Int, rest: Int) {
        switch goal {
        case .strength:    return (5, 5, 150)
        case .hypertrophy: return (4, 10, 75)
        case .cutting:     return (3, 15, 45)
        case .cardio:      return (1, 1, 60)
        }
    }

    // MARK: - Días de cardio

    private static func cardioDays(count: Int, catalog: [Exercise], seed: Int) -> [GeneratedDay] {
        struct CardioTemplate {
            let name: String, detail: String, symbol: String, colorHex: String, note: String
            let extraCore: Bool
        }
        let templates = [
            CardioTemplate(name: "Cardio continuo", detail: "Ritmo constante", symbol: "figure.run",
                            colorHex: "C86F6F", note: "30-40 min a ritmo constante, zona aeróbica (puedes hablar sin ahogarte).", extraCore: false),
            CardioTemplate(name: "Intervalos", detail: "HIIT", symbol: "bolt.fill",
                            colorHex: "E8A06B", note: "8-10 series de 30 s fuerte / 90 s suave.", extraCore: false),
            CardioTemplate(name: "Cardio + core", detail: "Resistencia y abdomen", symbol: "figure.core.training",
                            colorHex: "8A8FC8", note: "20-25 min de cardio suave, luego el bloque de core.", extraCore: true)
        ]
        var days: [GeneratedDay] = []
        for i in 0..<max(1, count) {
            let template = templates[i % templates.count]
            let offset = i + seed
            let cardioExercise = pick(from: catalog, group: .cardio, count: 1, offset: offset, nameFilter: nil).first
            var exercises: [GeneratedExercise] = []
            if let cardioExercise {
                exercises.append(GeneratedExercise(exercise: cardioExercise, sets: 1, reps: 1, restSeconds: 0, note: template.note))
            }
            if template.extraCore {
                for core in pick(from: catalog, group: .core, count: 2, offset: offset, nameFilter: nil) {
                    exercises.append(GeneratedExercise(exercise: core, sets: 3, reps: 15, restSeconds: 45, note: ""))
                }
            }
            days.append(GeneratedDay(name: "\(template.name) \(days.count + 1)", detail: template.detail,
                                      symbol: template.symbol, colorHex: template.colorHex, exercises: exercises))
        }
        return days
    }

    // MARK: - Selección de ejercicios

    /// Coge `count` ejercicios de un grupo muscular, rotando según `offset`
    /// para que las variantes A/B/C de un mismo split no salgan idénticas.
    /// Favoritos primero, luego ejercicios de barra/máquina (más "compuestos").
    private static func pick(from catalog: [Exercise], group: MuscleGroup, count: Int, offset: Int, nameFilter: ((String) -> Bool)?) -> [Exercise] {
        var pool = catalog.filter { $0.muscleGroup == group }
        if let nameFilter { pool = pool.filter { nameFilter($0.name) } }
        guard !pool.isEmpty else { return [] }

        pool.sort { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            let ra = compoundRank(a.equipment), rb = compoundRank(b.equipment)
            if ra != rb { return ra < rb }
            return a.name < b.name
        }

        var result: [Exercise] = []
        var index = offset % pool.count
        var seen = Set<Int>()
        while result.count < count && seen.count < pool.count {
            if !seen.contains(index) {
                result.append(pool[index])
                seen.insert(index)
            }
            index = (index + 1) % pool.count
        }
        return result
    }

    private static func compoundRank(_ equipment: Equipment) -> Int {
        switch equipment {
        case .barbell:    return 0
        case .machine:    return 1
        case .cable:      return 2
        case .dumbbell:   return 3
        case .kettlebell: return 4
        case .bodyweight: return 5
        case .band:       return 6
        }
    }

    private static func isTriceps(_ name: String) -> Bool {
        ["tríceps", "francés", "fondos", "patada"].contains { name.folded.contains($0.folded) }
    }

    private static func isBiceps(_ name: String) -> Bool {
        name.folded.contains("curl")
    }
}
