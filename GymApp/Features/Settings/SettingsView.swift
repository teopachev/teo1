import SwiftUI
import SwiftData

/// Mantenimiento de los datos y explicación de cómo calcula la app.
struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @Query private var exercises: [Exercise]
    @Query private var routines: [Routine]
    @Query private var sessions: [WorkoutSession]
    @Query private var weightEntries: [BodyWeightEntry]

    @AppStorage("barWeightKg") private var barWeight: Double = 20
    @AppStorage("weeklySessionGoal") private var weeklyGoal: Int = 4

    @State private var confirmingWipeHistory = false
    @State private var confirmingWipeAll = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                    header
                    trainingCard
                    dataCard
                    aboutCard
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(ScreenBackground())
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .alert("¿Borrar todo el historial de entrenos?", isPresented: $confirmingWipeHistory) {
            Button("Cancelar", role: .cancel) {}
            Button("Borrar", role: .destructive) { wipeHistory() }
        } message: {
            Text("Se borran todas las sesiones registradas. Tus rutinas y tu catálogo de ejercicios se quedan como están.")
        }
        .alert("¿Borrar absolutamente todo?", isPresented: $confirmingWipeAll) {
            Button("Cancelar", role: .cancel) {}
            Button("Borrar todo", role: .destructive) { wipeAll() }
        } message: {
            Text("Se borran las sesiones, las rutinas y el catálogo de ejercicios. No se puede deshacer.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: "Versión 1.0")
            Text("Ajustes")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.top, 8)
    }

    private var trainingCard: some View {
        VStack(spacing: 14) {
            SectionHeader(title: "Entrenamiento")
            HStack {
                Text("Objetivo semanal")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Stepper(value: $weeklyGoal, in: 1...7) {
                    Text("\(weeklyGoal) sesiones")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                }
                .fixedSize()
            }
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack {
                Text("Peso de la barra")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Stepper(value: $barWeight, in: 0...50, step: 2.5) {
                    Text(Fmt.weight(barWeight))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                }
                .fixedSize()
            }
            Text("El objetivo semanal marca el anillo de la pantalla Hoy. El peso de barra es el punto de partida de la calculadora de discos.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textTertiary)
        }
        .card()
    }

    private var dataCard: some View {
        VStack(spacing: 14) {
            SectionHeader(title: "Datos")

            HStack(spacing: 10) {
                StatTile(label: "Ejercicios", value: "\(exercises.count)")
                StatTile(label: "Rutinas", value: "\(routines.count)")
                StatTile(label: "Entrenos", value: "\(sessions.count)")
            }

            Button { confirmingWipeHistory = true } label: {
                dataRow("Borrar historial de entrenos", "clock.arrow.circlepath",
                        detail: "Rutinas y ejercicios se conservan", tint: Palette.warning)
            }
            .buttonStyle(.plain)

            Button { confirmingWipeAll = true } label: {
                dataRow("Borrar absolutamente todo", "trash", detail: "Sesiones, rutinas y ejercicios", tint: Palette.over)
            }
            .buttonStyle(.plain)
        }
        .card()
    }

    private func dataRow(_ title: String, _ symbol: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textTertiary)
        }
        .padding(.vertical, 4)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Cómo calcula la app")
            Text("El 1RM (el máximo que podrías levantar en una repetición) se estima con la fórmula de Epley a partir del peso y las reps de cada serie. Es una estimación: cuanto más te alejas de 1-3 reps, menos precisa es.\n\nEl volumen de una sesión es la suma de reps × peso de todas las series de trabajo (las de calentamiento no cuentan). Las marcas personales (PR) se calculan sobre el peso máximo levantado, comparando con todo tu historial.\n\nTodo se guarda solo en este iPhone: nada sale de aquí.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func wipeHistory() {
        for session in sessions { context.delete(session) }
        for entry in weightEntries { context.delete(entry) }
        try? context.save()
    }

    private func wipeAll() {
        for session in sessions { context.delete(session) }
        for routine in routines { context.delete(routine) }
        for exercise in exercises { context.delete(exercise) }
        for entry in weightEntries { context.delete(entry) }
        try? context.save()
    }
}
