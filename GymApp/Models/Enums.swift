import Foundation

// MARK: - Grupo muscular

/// Grupo muscular principal que trabaja un ejercicio. Lleva su color e icono
/// para mostrarse de forma consistente en etiquetas, listas y resúmenes.
enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Hashable {
    case chest
    case back
    case shoulders
    case arms
    case legs
    case glutes
    case core
    case fullBody
    case cardio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: return "Pecho"
        case .back: return "Espalda"
        case .shoulders: return "Hombros"
        case .arms: return "Brazos"
        case .legs: return "Piernas"
        case .glutes: return "Glúteos"
        case .core: return "Core"
        case .fullBody: return "Cuerpo completo"
        case .cardio: return "Cardio"
        }
    }

    var symbol: String {
        switch self {
        case .chest: return "figure.arms.open"
        case .back: return "figure.stand"
        case .shoulders: return "figure.strengthtraining.functional"
        case .arms: return "dumbbell.fill"
        case .legs: return "figure.walk"
        case .glutes: return "figure.cross.training"
        case .core: return "figure.core.training"
        case .fullBody: return "figure.mixed.cardio"
        case .cardio: return "heart.fill"
        }
    }

    /// Color en hexadecimal (sin almohadilla) para teñir la etiqueta.
    var colorHex: String {
        switch self {
        case .chest: return "C88A8A"
        case .back: return "6FA0C8"
        case .shoulders: return "C8B36F"
        case .arms: return "8A8FC8"
        case .legs: return "6FC8A0"
        case .glutes: return "C86FA0"
        case .core: return "C8956F"
        case .fullBody: return "9C9CA6"
        case .cardio: return "E8A06B"
        }
    }
}

// MARK: - Equipamiento

enum Equipment: String, Codable, CaseIterable, Identifiable, Hashable {
    case barbell
    case dumbbell
    case machine
    case cable
    case bodyweight
    case kettlebell
    case band

    var id: String { rawValue }

    var title: String {
        switch self {
        case .barbell: return "Barra"
        case .dumbbell: return "Mancuerna"
        case .machine: return "Máquina"
        case .cable: return "Polea"
        case .bodyweight: return "Peso corporal"
        case .kettlebell: return "Kettlebell"
        case .band: return "Banda"
        }
    }

    var symbol: String {
        switch self {
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbell: return "dumbbell.fill"
        case .machine: return "gearshape.2.fill"
        case .cable: return "cable.connector"
        case .bodyweight: return "figure.gymnastics"
        case .kettlebell: return "figure.kickboxing"
        case .band: return "alternatingcurrent"
        }
    }
}

// MARK: - Día de la semana

/// Día de la semana con lunes como primer día (raw 1...7), independiente del
/// `Calendar` del sistema, para programar rutinas de forma estable.
enum Weekday: Int, Codable, CaseIterable, Identifiable, Hashable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: Int { rawValue }

    var short: String {
        switch self {
        case .monday: return "L"
        case .tuesday: return "M"
        case .wednesday: return "X"
        case .thursday: return "J"
        case .friday: return "V"
        case .saturday: return "S"
        case .sunday: return "D"
        }
    }

    var title: String {
        switch self {
        case .monday: return "Lunes"
        case .tuesday: return "Martes"
        case .wednesday: return "Miércoles"
        case .thursday: return "Jueves"
        case .friday: return "Viernes"
        case .saturday: return "Sábado"
        case .sunday: return "Domingo"
        }
    }

    /// Día actual mapeado a esta escala (lunes = 1).
    static func current(_ date: Date = .now, calendar: Calendar = .current) -> Weekday {
        // Calendar usa domingo = 1; lo convertimos a lunes = 1.
        let weekday = calendar.component(.weekday, from: date) // 1 (dom) ... 7 (sáb)
        let mondayBased = ((weekday + 5) % 7) + 1               // 1 (lun) ... 7 (dom)
        return Weekday(rawValue: mondayBased) ?? .monday
    }
}

// MARK: - Objetivo del plan

/// El objetivo con el que se genera un plan de rutinas: cambia el esquema de
/// series/reps/descanso y qué ejercicios se priorizan.
enum TrainingGoal: String, Codable, CaseIterable, Identifiable, Hashable {
    case strength
    case hypertrophy
    case cutting
    case cardio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength:    return "Fuerza"
        case .hypertrophy: return "Volumen"
        case .cutting:     return "Definición"
        case .cardio:      return "Cardio"
        }
    }

    var subtitle: String {
        switch self {
        case .strength:    return "Pocas reps, mucho peso"
        case .hypertrophy: return "Más series, hipertrofia"
        case .cutting:     return "Reps altas y cardio"
        case .cardio:      return "Resistencia cardiovascular"
        }
    }

    var symbol: String {
        switch self {
        case .strength:    return "bolt.fill"
        case .hypertrophy: return "chart.bar.fill"
        case .cutting:     return "flame.fill"
        case .cardio:      return "heart.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .strength:    return "6FA0C8"
        case .hypertrophy: return "8A8FC8"
        case .cutting:     return "E8A06B"
        case .cardio:      return "C86F6F"
        }
    }
}

// MARK: - Nivel de experiencia

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable, Hashable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner:     return "Principiante"
        case .intermediate: return "Intermedio"
        case .advanced:     return "Avanzado"
        }
    }

    var detail: String {
        switch self {
        case .beginner:     return "Menos de 1 año entrenando"
        case .intermediate: return "1-3 años entrenando"
        case .advanced:     return "Más de 3 años entrenando"
        }
    }

    /// Multiplicador sobre el número de ejercicios/series por sesión.
    var volumeMultiplier: Double {
        switch self {
        case .beginner:     return 0.75
        case .intermediate: return 1.0
        case .advanced:     return 1.2
        }
    }
}
