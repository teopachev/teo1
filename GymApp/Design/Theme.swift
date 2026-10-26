import SwiftUI

// MARK: - Color desde hexadecimal

extension Color {
    /// Crea un color a partir de "RRGGBB" o "RRGGBBAA" (con o sin almohadilla).
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: Double
        switch cleaned.count {
        case 8:
            r = Double((value & 0xFF00_0000) >> 24) / 255
            g = Double((value & 0x00FF_0000) >> 16) / 255
            b = Double((value & 0x0000_FF00) >> 8) / 255
            a = Double(value & 0x0000_00FF) / 255
        default:
            r = Double((value & 0xFF0000) >> 16) / 255
            g = Double((value & 0x00FF00) >> 8) / 255
            b = Double(value & 0x0000FF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Paleta "Graphite"

/// Sistema monocromo inspirado en el acabado grafito de Apple: fondo frío
/// profundo, superficies de aluminio que suben por elevación y un único
/// acento de acero. El oro de "récord" es la única otra nota de color, y
/// solo aparece cuando bates una marca personal.
enum Palette {
    // Fondos
    static let canvas      = Color(hex: "0A0A0C")
    static let canvasDeep  = Color(hex: "040405")
    static let surface     = Color(hex: "18181B")
    static let surfaceHi   = Color(hex: "222226")
    static let surfaceTop  = Color(hex: "2A2A2F")

    // Trazos
    static let hairline       = Color.white.opacity(0.08)
    static let hairlineStrong = Color.white.opacity(0.14)

    // Texto
    static let textPrimary   = Color(hex: "F2F2F5")
    static let textSecondary = Color(hex: "9D9DA6")
    static let textTertiary  = Color(hex: "66666E")

    // Acento único: acero, el color del hierro.
    static let accent = Color(hex: "6FA0C8")

    // Semánticos
    static let success = Color(hex: "6FC89A")  // serie completada / racha viva
    static let record  = Color(hex: "E3B34D")  // marca personal (PR)
    static let warning = Color(hex: "C2A65A")
    static let over    = Color(hex: "B89A92")
    static let rest    = Color(hex: "8FA0C0")

    // Gradiente de las tarjetas de grafito.
    static let cardGradient = LinearGradient(
        colors: [Color(hex: "1E1E22"), Color(hex: "141416")],
        startPoint: .top,
        endPoint: .bottom
    )

    // Gradiente del bisel exterior del héroe.
    static let bezelGradient = LinearGradient(
        colors: [Color(hex: "2C2C31"), Color(hex: "151517")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Resplandor radial muy sutil para dar profundidad al fondo.
    static let ambientGlow = RadialGradient(
        colors: [Color.white.opacity(0.05), Color.clear],
        center: .top,
        startRadius: 4,
        endRadius: 520
    )
}

// MARK: - Métricas

enum Metrics {
    static let cardRadius: CGFloat = 24
    static let innerRadius: CGFloat = 18
    static let tileRadius: CGFloat = 18
    static let pillRadius: CGFloat = 999

    static let screenPadding: CGFloat = 20
    static let sectionGap: CGFloat = 26
    static let cardPadding: CGFloat = 18
}

// MARK: - Curvas de animación (física tipo iOS)

extension Animation {
    /// Muelle suave para apariciones y cambios de estado.
    static let smoothSpring = Animation.spring(response: 0.5, dampingFraction: 0.82)
    /// Muelle más vivo para toques y micro-interacciones.
    static let snappySpring = Animation.spring(response: 0.34, dampingFraction: 0.72)
}

// MARK: - Tipografía

extension Font {
    /// Número grande de héroe (con dígitos de ancho fijo).
    static func hero(_ size: CGFloat = 40) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
    /// Cifra destacada dentro de tarjetas.
    static func figure(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
    /// Etiqueta tipo "eyebrow" en versales.
    static let eyebrow = Font.system(size: 11, weight: .semibold, design: .default)
}

extension Text {
    /// Aplica dígitos monoespaciados para que las cifras no "bailen".
    func tabularFigures() -> Text { self.monospacedDigit() }
}
