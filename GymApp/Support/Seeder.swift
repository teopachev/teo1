import Foundation
import SwiftData

/// Carga el catálogo de ejercicios habituales la primera vez que se abre la
/// app, para no empezar con la biblioteca vacía.
enum Seeder {

    struct Item {
        let name: String
        let group: MuscleGroup
        let equipment: Equipment
    }

    static let catalog: [Item] = [
        // Pecho
        Item(name: "Press banca", group: .chest, equipment: .barbell),
        Item(name: "Press banca inclinado", group: .chest, equipment: .barbell),
        Item(name: "Press banca con mancuernas", group: .chest, equipment: .dumbbell),
        Item(name: "Press inclinado con mancuernas", group: .chest, equipment: .dumbbell),
        Item(name: "Aperturas con mancuernas", group: .chest, equipment: .dumbbell),
        Item(name: "Cruces en polea", group: .chest, equipment: .cable),
        Item(name: "Fondos en paralelas", group: .chest, equipment: .bodyweight),
        Item(name: "Press en máquina", group: .chest, equipment: .machine),
        Item(name: "Flexiones", group: .chest, equipment: .bodyweight),

        // Espalda
        Item(name: "Dominadas", group: .back, equipment: .bodyweight),
        Item(name: "Jalón al pecho", group: .back, equipment: .cable),
        Item(name: "Remo con barra", group: .back, equipment: .barbell),
        Item(name: "Remo con mancuerna", group: .back, equipment: .dumbbell),
        Item(name: "Remo en polea baja", group: .back, equipment: .cable),
        Item(name: "Peso muerto", group: .back, equipment: .barbell),
        Item(name: "Peso muerto rumano", group: .back, equipment: .barbell),
        Item(name: "Remo en máquina", group: .back, equipment: .machine),
        Item(name: "Pull-over en polea", group: .back, equipment: .cable),

        // Hombros
        Item(name: "Press militar", group: .shoulders, equipment: .barbell),
        Item(name: "Press de hombros con mancuernas", group: .shoulders, equipment: .dumbbell),
        Item(name: "Elevaciones laterales", group: .shoulders, equipment: .dumbbell),
        Item(name: "Elevaciones frontales", group: .shoulders, equipment: .dumbbell),
        Item(name: "Pájaros (deltoide posterior)", group: .shoulders, equipment: .dumbbell),
        Item(name: "Elevaciones laterales en polea", group: .shoulders, equipment: .cable),
        Item(name: "Encogimientos (trapecio)", group: .shoulders, equipment: .barbell),

        // Brazos
        Item(name: "Curl con barra", group: .arms, equipment: .barbell),
        Item(name: "Curl con mancuernas", group: .arms, equipment: .dumbbell),
        Item(name: "Curl martillo", group: .arms, equipment: .dumbbell),
        Item(name: "Curl en polea", group: .arms, equipment: .cable),
        Item(name: "Press francés", group: .arms, equipment: .barbell),
        Item(name: "Extensión de tríceps en polea", group: .arms, equipment: .cable),
        Item(name: "Fondos en banco", group: .arms, equipment: .bodyweight),
        Item(name: "Patada de tríceps", group: .arms, equipment: .dumbbell),

        // Piernas
        Item(name: "Sentadilla", group: .legs, equipment: .barbell),
        Item(name: "Sentadilla frontal", group: .legs, equipment: .barbell),
        Item(name: "Prensa de piernas", group: .legs, equipment: .machine),
        Item(name: "Zancadas", group: .legs, equipment: .dumbbell),
        Item(name: "Extensión de cuádriceps", group: .legs, equipment: .machine),
        Item(name: "Curl femoral", group: .legs, equipment: .machine),
        Item(name: "Elevación de talones (gemelo)", group: .legs, equipment: .machine),
        Item(name: "Sentadilla búlgara", group: .legs, equipment: .dumbbell),
        Item(name: "Hip thrust", group: .glutes, equipment: .barbell),

        // Glúteos
        Item(name: "Patada de glúteo en polea", group: .glutes, equipment: .cable),
        Item(name: "Abducción de cadera en máquina", group: .glutes, equipment: .machine),

        // Core
        Item(name: "Plancha", group: .core, equipment: .bodyweight),
        Item(name: "Crunch abdominal", group: .core, equipment: .bodyweight),
        Item(name: "Elevación de piernas colgado", group: .core, equipment: .bodyweight),
        Item(name: "Rueda abdominal", group: .core, equipment: .bodyweight),
        Item(name: "Rusian twist", group: .core, equipment: .dumbbell),

        // Cuerpo completo / cardio
        Item(name: "Kettlebell swing", group: .fullBody, equipment: .kettlebell),
        Item(name: "Burpees", group: .fullBody, equipment: .bodyweight),
        Item(name: "Carrera continua", group: .cardio, equipment: .bodyweight),
        Item(name: "Bicicleta estática", group: .cardio, equipment: .machine),
        Item(name: "Remo (máquina de cardio)", group: .cardio, equipment: .machine),
        Item(name: "Comba", group: .cardio, equipment: .bodyweight)
    ]

    private static let versionKey = "exerciseSeedVersion"
    private static let currentVersion = 1

    /// Se ejecuta en cada arranque, pero solo hace algo si el catálogo está
    /// vacío. Los ejercicios que hayas creado tú no se tocan nunca.
    static func seedIfNeeded(_ context: ModelContext, existing: [Exercise]) {
        guard existing.isEmpty else { return }
        for item in catalog {
            context.insert(Exercise(name: item.name, muscleGroup: item.group, equipment: item.equipment))
        }
        UserDefaults.standard.set(currentVersion, forKey: versionKey)
        try? context.save()
    }

    /// Da de alta los ejercicios de fábrica que falten, comparando por nombre
    /// sin tildes ni mayúsculas. No toca lo que ya tengas.
    @discardableResult
    static func addMissing(_ context: ModelContext, existing: [Exercise]) -> Int {
        let names = Set(existing.map { $0.name.folded })
        var added = 0
        for item in catalog where !names.contains(item.name.folded) {
            context.insert(Exercise(name: item.name, muscleGroup: item.group, equipment: item.equipment))
            added += 1
        }
        if added > 0 { try? context.save() }
        return added
    }
}
