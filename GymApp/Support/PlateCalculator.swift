import Foundation

/// Reparte los discos que hay que poner en cada lado de la barra para llegar
/// a un peso objetivo, con el juego de discos olímpico habitual.
enum PlateCalculator {
    static let standardPlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    struct Breakdown {
        /// Discos por lado, de más pesado a más ligero, con su cantidad.
        var plates: [(weight: Double, count: Int)]
        var reachedWeight: Double
        var barWeight: Double
        var isExact: Bool
    }

    /// `target` es el peso total de la barra (incluye la propia barra).
    static func breakdown(target: Double, barWeight: Double, availablePlates: [Double] = standardPlates) -> Breakdown {
        let perSideTarget = max(0, (target - barWeight) / 2)
        var remaining = perSideTarget
        var plates: [(weight: Double, count: Int)] = []

        for plate in availablePlates.sorted(by: >) {
            guard plate > 0 else { continue }
            var count = 0
            // Pequeño margen para el redondeo de decimales (1.25 kg, etc.).
            while remaining + 0.001 >= plate {
                remaining -= plate
                count += 1
            }
            if count > 0 { plates.append((plate, count)) }
        }

        let usedPerSide = perSideTarget - remaining
        let reached = barWeight + usedPerSide * 2
        // Compara contra el objetivo real, no solo contra lo repartido: si el
        // objetivo pedido está por debajo del propio peso de la barra, nunca
        // se alcanza aunque no sobre nada por repartir.
        return Breakdown(plates: plates, reachedWeight: reached, barWeight: barWeight, isExact: abs(reached - target) < 0.01)
    }
}
