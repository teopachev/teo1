import SwiftUI
import SwiftData
import Charts

/// Progreso de un ejercicio: evolución del 1RM estimado, marcas personales y
/// el historial de series tal y como se hicieron. Todo sale de las sesiones
/// reales, nunca de la plantilla de una rutina.
struct ExerciseDetailView: View {
    @Bindable var exercise: Exercise

    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var showingEditor = false

    private var history: [(date: Date, set: LoggedSet)] {
        TrainingCalculator.history(of: exercise, in: sessions)
    }

    private var records: TrainingCalculator.PersonalRecords {
        TrainingCalculator.personalRecords(from: history)
    }

    /// Mejor serie de cada día entrenado, para no saturar el gráfico con
    /// varias series del mismo día.
    private var chartPoints: [(date: Date, oneRepMax: Double)] {
        var byDay: [Date: Double] = [:]
        let calendar = Calendar.current
        for entry in history where !entry.set.isWarmup {
            let day = calendar.startOfDay(for: entry.date)
            byDay[day] = max(byDay[day] ?? 0, entry.set.estimatedOneRepMax)
        }
        return byDay.map { (date: $0.key, oneRepMax: $0.value) }.sorted { $0.date < $1.date }
    }

    /// Sesiones que incluyen este ejercicio, más recientes primero.
    private var sessionsWithExercise: [(session: WorkoutSession, item: SessionExercise)] {
        sessions.compactMap { session in
            guard let item = session.exercises.first(where: {
                $0.exercise?.persistentModelID == exercise.persistentModelID
                    || $0.exerciseName.folded == exercise.name.folded
            }) else { return nil }
            return (session, item)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                hero
                if chartPoints.count >= 2 {
                    chartCard
                }
                if history.isEmpty {
                    EmptyStateView(symbol: "chart.line.uptrend.xyaxis", title: "Sin historial todavía",
                                   message: "En cuanto registres una serie de \(exercise.name) en un entreno, aparecerá aquí.")
                        .card()
                } else {
                    historyCard
                }
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(ScreenBackground())
        .navigationTitle(exercise.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.snappySpring) { exercise.isFavorite.toggle() }
                } label: {
                    Image(systemName: exercise.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(exercise.isFavorite ? Palette.record : Palette.textSecondary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showingEditor = true } label: {
                    Label("Editar", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditor) { ExerciseEditorView(existing: exercise) }
    }

    // MARK: - Cabecera

    private var hero: some View {
        BezelCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    IconBadge(symbol: exercise.symbol, color: Color(hex: exercise.colorHex), size: 50)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(exercise.muscleGroup.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: exercise.colorHex))
                        Text(exercise.equipment.title)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    StatTile(label: "Mejor peso", value: records.maxWeight > 0 ? Fmt.weight(records.maxWeight) : "—",
                             detail: records.maxWeight > 0 ? Fmt.reps(records.maxWeightReps) : nil,
                             symbol: "trophy.fill", tint: Palette.record)
                    StatTile(label: "1RM estimado", value: records.maxOneRepMax > 0 ? Fmt.weight(records.maxOneRepMax) : "—",
                             symbol: "bolt.fill", tint: Palette.accent)
                }
                if records.maxVolumeInSession > 0 {
                    StatTile(label: "Mejor volumen (sesión)", value: Fmt.volume(records.maxVolumeInSession),
                              symbol: "square.stack.3d.up.fill", tint: Palette.textPrimary)
                }
            }
        }
    }

    // MARK: - Gráfico

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Evolución del 1RM")
            Chart(chartPoints, id: \.date) { point in
                LineMark(x: .value("Fecha", point.date), y: .value("1RM", point.oneRepMax))
                    .foregroundStyle(Palette.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                AreaMark(x: .value("Fecha", point.date), y: .value("1RM", point.oneRepMax))
                    .foregroundStyle(
                        LinearGradient(colors: [Palette.accent.opacity(0.22), .clear],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Fecha", point.date), y: .value("1RM", point.oneRepMax))
                    .foregroundStyle(point.oneRepMax == records.maxOneRepMax ? Palette.record : Palette.accent)
                    .symbolSize(point.oneRepMax == records.maxOneRepMax ? 70 : 30)
            }
            .frame(height: 170)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine().foregroundStyle(Palette.hairline)
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(Fmt.int(v)).font(.system(size: 10)).foregroundStyle(Palette.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(Palette.hairline)
                    AxisValueLabel {
                        if let d = value.as(Date.self) {
                            Text(Fmt.dayMonth(d)).font(.system(size: 10)).foregroundStyle(Palette.textTertiary)
                        }
                    }
                }
            }
        }
        .card()
    }

    // MARK: - Historial

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Historial de sesiones")
            VStack(spacing: 0) {
                ForEach(Array(sessionsWithExercise.enumerated()), id: \.element.session.persistentModelID) { index, entry in
                    NavigationLink(value: entry.session) {
                        historyRow(entry.session, entry.item)
                    }
                    .buttonStyle(.plain)
                    if index < sessionsWithExercise.count - 1 {
                        Divider().overlay(Palette.hairline)
                    }
                }
            }
        }
        .card(padding: 6)
        .navigationDestination(for: WorkoutSession.self) { SessionDetailView(session: $0) }
    }

    private func historyRow(_ session: WorkoutSession, _ item: SessionExercise) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.weekdayDate(session.date))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                Text(item.orderedSets.filter { $0.isCompleted && !$0.isWarmup }
                    .map { "\($0.reps)×\(Fmt.loose($0.weight))" }
                    .joined(separator: "  ·  "))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let top = item.topSet {
                Text(Fmt.weight(top.weight))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(top.weight >= records.maxWeight ? Palette.record : Palette.textPrimary)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
    }
}
