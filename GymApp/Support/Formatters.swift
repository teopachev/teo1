import Foundation

/// Formateo de todo lo que se enseña en pantalla. Centralizado aquí para que
/// las cifras se vean igual en toda la app (separador de miles español, un
/// decimal en los pesos cuando hace falta).
enum Fmt {

    // MARK: Números

    private static let integer: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "es_ES")
        f.maximumFractionDigits = 0
        return f
    }()

    private static let oneDecimal: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "es_ES")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f
    }()

    /// Entero con separador de miles: 1.847
    static func int(_ value: Double) -> String {
        integer.string(from: NSNumber(value: value.rounded())) ?? "0"
    }

    /// Hasta un decimal, sin ceros de relleno: 72,5 · 80
    static func decimal(_ value: Double) -> String {
        oneDecimal.string(from: NSNumber(value: value)) ?? "0"
    }

    /// Entero si la cifra es redonda, con un decimal si no: 3 · 2,5
    static func loose(_ value: Double) -> String {
        value == value.rounded() ? int(value) : decimal(value)
    }

    // MARK: Entrenamiento

    /// Peso con un decimal cuando hace falta: "82,5 kg" · "80 kg"
    static func weight(_ kg: Double) -> String { "\(loose(kg)) kg" }

    /// Volumen (reps × peso), con separador de miles: "1.240 kg"
    static func volume(_ kg: Double) -> String { "\(int(kg)) kg" }

    static func reps(_ value: Int) -> String { value == 1 ? "1 rep" : "\(value) reps" }

    /// Cifra con signo, para variaciones: "+0,4 kg" · "−1,2 kg"
    static func signed(_ value: Double, unit: String = "kg") -> String {
        let sign = value > 0 ? "+" : (value < 0 ? "−" : "")
        let suffix = unit.isEmpty ? "" : " \(unit)"
        return "\(sign)\(decimal(abs(value)))\(suffix)"
    }

    /// Convierte segundos de descanso en un texto corto ("90 s", "1:30").
    static func restLabel(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) s" }
        let minutes = seconds / 60
        let rest = seconds % 60
        return rest == 0 ? "\(minutes) min" : String(format: "%d:%02d", minutes, rest)
    }

    /// Reloj de cronómetro: "12:04" o, pasada la hora, "1:02:04".
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    /// Duración de sesión en formato compacto: "48 min" · "1h 12min"
    static func minutes(_ totalSeconds: Int) -> String {
        let mins = max(1, (totalSeconds + 59) / 60)
        if mins < 60 { return "\(mins) min" }
        let h = mins / 60, m = mins % 60
        return m == 0 ? "\(h) h" : "\(h)h \(m)min"
    }

    // MARK: Fechas

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.setLocalizedDateFormatFromTemplate(format)
        return f
    }

    private static let time = formatter("HHmm")
    private static let dayMonth = formatter("dMMM")
    private static let full = formatter("EEEEdMMMM")
    private static let shortDay = formatter("EEEdMMM")

    static func hour(_ date: Date) -> String { time.string(from: date) }

    /// Título del día: "Hoy", "Ayer" o "mar, 12 sep".
    static func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoy" }
        if calendar.isDateInYesterday(date) { return "Ayer" }
        return shortDay.string(from: date).capitalizedFirst
    }

    /// Día completo para cabeceras: "martes, 12 de septiembre".
    static func longDay(_ date: Date) -> String {
        full.string(from: date).capitalizedFirst
    }

    /// Día y mes corto: "12 sep".
    static func dayMonth(_ date: Date) -> String {
        dayMonth.string(from: date)
    }

    /// Día de la semana + fecha corta: "mar, 12 sep".
    static func weekdayDate(_ date: Date) -> String {
        shortDay.string(from: date).capitalizedFirst
    }

    /// Mes y año: "septiembre 2026".
    static func monthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return formatter.string(from: date).capitalizedFirst
    }
}

extension String {
    /// Pone en mayúscula solo la primera letra, sin tocar el resto.
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
