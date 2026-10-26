import SwiftUI
import SwiftData

/// Detalle de una rutina: sus ejercicios con las series objetivo, y el botón
/// para arrancar una sesión real a partir de ella.
struct RoutineDetailView: View {
    @Bindable var routine: Routine

    @State private var showingSession = false
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                hero
                if !routine.exercises.isEmpty {
                    PrimaryActionButton(title: "Empezar entreno", symbol: "play.fill",
                                        tint: Color(hex: routine.colorHex), fullWidth: true) {
                        showingSession = true
                    }
                }
                ForEach(routine.orderedExercises) { item in
                    RoutineExerciseBlock(item: item)
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(ScreenBackground())
        .navigationTitle(routine.name.isEmpty ? "Rutina" : routine.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingEditor = true } label: {
                    Label("Editar", systemImage: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showingEditor) { RoutineEditorView(routine: routine, isNew: false) }
        .fullScreenCover(isPresented: $showingSession) { ActiveSessionView(routine: routine) }
    }

    private var hero: some View {
        BezelCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    IconBadge(symbol: routine.symbol, color: Color(hex: routine.colorHex), size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(routine.name.isEmpty ? "Rutina" : routine.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        if !routine.detail.isEmpty {
                            Text(routine.detail)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    miniMetric("\(routine.exercises.count)", "Ejercicios")
                    miniMetric("\(routine.totalSets)", "Series")
                    miniMetric(Fmt.minutes(routine.estimatedMinutes * 60), "Estimado")
                }
                if !routine.scheduledWeekdays.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.textTertiary)
                        Text(routine.scheduledWeekdays.map(\.title).joined(separator: " · "))
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
        }
    }

    private func miniMetric(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.figure(18)).foregroundStyle(Palette.textPrimary)
            Text(caption).font(.system(size: 11)).foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

// MARK: - Bloque de un ejercicio

struct RoutineExerciseBlock: View {
    @Bindable var item: RoutineExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconBadge(symbol: item.exercise?.symbol ?? "dumbbell.fill",
                          color: Color(hex: item.exercise?.colorHex ?? "9C9CA6"), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.exercise?.name ?? "Ejercicio")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(item.schemeSummary)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer(minLength: 0)
                TagPill(text: Fmt.restLabel(item.restSeconds), color: Palette.rest, symbol: "timer")
            }
            VStack(spacing: 0) {
                ForEach(Array(item.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                    routineSetRow(set, index: index + 1)
                    if index < item.orderedSets.count - 1 {
                        Divider().overlay(Palette.hairline)
                    }
                }
            }
            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04)))
            }
        }
        .card()
    }

    private func routineSetRow(_ set: RoutineSet, index: Int) -> some View {
        HStack(spacing: 14) {
            Text(set.isWarmup ? "W" : "\(index)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.textTertiary)
                .frame(width: 22)
            Text(Fmt.reps(set.targetReps))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
            if let load = set.loadText {
                Text("· \(load)")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
    }
}
