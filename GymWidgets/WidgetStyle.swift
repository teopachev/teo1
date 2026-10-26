import SwiftUI

extension Color {
    /// Copia mínima del ayudante del tema: una extensión no puede ver la
    /// carpeta de diseño de la app sin arrastrarla entera.
    init(widgetHex hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            .sRGB,
            red: Double((value & 0xFF0000) >> 16) / 255,
            green: Double((value & 0x00FF00) >> 8) / 255,
            blue: Double(value & 0x0000FF) / 255,
            opacity: 1
        )
    }
}

enum W {
    static let canvas  = Color(widgetHex: WidgetPalette.canvasHex)
    static let accent  = Color(widgetHex: WidgetPalette.accentHex)
    static let record  = Color(widgetHex: WidgetPalette.recordHex)
    static let text    = Color(widgetHex: WidgetPalette.textPrimaryHex)
    static let dim     = Color(widgetHex: WidgetPalette.textDimHex)
    static let faint   = Color(widgetHex: WidgetPalette.textFaintHex)
}

/// Anillo de progreso, versión reducida para los widgets.
struct WidgetRing: View {
    var value: Double
    var tint: Color
    var lineWidth: CGFloat = 9

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
