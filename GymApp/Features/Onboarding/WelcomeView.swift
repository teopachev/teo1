import SwiftUI

/// Pantalla de bienvenida, una sola vez. Puramente informativa: no bloquea
/// ningún flujo, solo explica de un vistazo qué hace la app antes de
/// soltarte en una pantalla "Hoy" que si no, arranca bastante vacía.
struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: Metrics.sectionGap) {
                Spacer(minLength: 8)

                ZStack {
                    Circle().fill(Palette.accent.opacity(0.14)).frame(width: 108, height: 108)
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }

                VStack(spacing: 8) {
                    Text("Bienvenido a Gimnasio")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.center)
                    Text("Apunta cada serie con su peso real, para ver tu progreso de verdad y no perder ninguna marca.")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)

                VStack(spacing: 14) {
                    point("list.bullet.rectangle.fill", "Crea rutinas", "Ejercicios, series y días de la semana.")
                    point("stopwatch.fill", "Entrena en directo", "Cronómetro, descanso entre series y sugerencia de peso.")
                    point("chart.xyaxis.line", "Mira tu progreso", "1RM estimado, marcas personales y volumen semanal.")
                }
                .padding(.horizontal, Metrics.screenPadding)

                Spacer(minLength: 8)

                PrimaryActionButton(title: "Empezar", symbol: "arrow.right", fullWidth: true) {
                    hasSeenWelcome = true
                    dismiss()
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 24)
            }
        }
    }

    private func point(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            IconBadge(symbol: symbol, color: Palette.accent, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }
}
