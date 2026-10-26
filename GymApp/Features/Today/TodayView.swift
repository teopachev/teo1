import SwiftUI
import SwiftData

/// Pantalla de inicio. El hero de arriba resume la semana de un vistazo
/// (sesiones cumplidas contra tu objetivo, racha, volumen) con un mensaje
/// corto que cambia según tu situación real, al estilo de los paneles de
/// entrenamiento tipo WHOOP; debajo, el plan de hoy y el último entreno.
struct TodayView: View {
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var weightEntries: [BodyWeightEntry]

    @AppStorage("weeklySessionGoal") private var weeklyGoal: Int = 4

    @State private var startingRoutine: Routine?
    @State private var startingFreeSession = false
    @State private var showingPlanGenerator = false
    @State private var loggingWeight = false

    private let calendar = Calendar.current

    private var todayRoutine: Routine? {
        routines.first { $0.scheduledDays.contains(Weekday.current().rawValue) }
    }

    private var lastSession: WorkoutSession? { sessions.first }

    private var sessionsThisWeek: Int {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        return sessions.filter { $0.date >= start }.count
    }

    private var didTrainToday: Bool {
        sessions.contains { calendar.isDateInToday($0.date) }
    }

    private var daysSinceLastSession: Int? {
        guard let last = lastSession?.date else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: .now)).day
    }

    private var weekVolume: Double {
        guard let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) else { return 0 }
        return TrainingCalculator.volume(in: sessions, from: start)
    }

    private var streak: Int { TrainingCalculator.weekStreak(sessions) }

    private var recentRecord: TrainingCalculator.RecentRecord? {
        guard !routines.isEmpty || !sessions.isEmpty else { return nil }
        let exercises = Set(sessions.flatMap { $0.exercises.compactMap(\.exercise) })
        return TrainingCalculator.recentPersonalRecords(exercises: Array(exercises), sessions: sessions, withinDays: 5).first
    }

    private var ringProgress: Double {
        weeklyGoal > 0 ? Double(sessionsThisWeek) / Double(weeklyGoal) : 0
    }

    private var ringColor: Color { ringProgress >= 1 ? Palette.record : Palette.accent }

    /// Próximas rutinas programadas esta semana, después de hoy.
    private var upcomingThisWeek: [(weekday: Weekday, routine: Routine)] {
        let todayRaw = Weekday.current().rawValue
        return Weekday.allCases
            .filter { $0.rawValue > todayRaw }
            .compactMap { day in routines.first { $0.scheduledDays.contains(day.rawValue) }.map { (day, $0) } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                    header
                    heroCard
                    quickActionsRow
                    WeekProgressStrip(routines: routines, sessions: sessions)
                    if let recentRecord {
                        recentRecordBanner(recentRecord)
                    }
                    planCard
                    if !upcomingThisWeek.isEmpty {
                        upcomingCard
                    }
                    bodyWeightCard
                    if let lastSession {
                        lastSessionCard(lastSession)
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(ScreenBackground())
            .navigationDestination(for: WorkoutSession.self) { SessionDetailView(session: $0) }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .fullScreenCover(item: $startingRoutine) { ActiveSessionView(routine: $0) }
            .fullScreenCover(isPresented: $startingFreeSession) { ActiveSessionView(routine: nil) }
            .sheet(isPresented: $showingPlanGenerator) { PlanGeneratorView() }
            .sheet(isPresented: $loggingWeight) { LogWeightView() }
        }
    }

    // MARK: - Accesos rápidos

    private var quickActionsRow: some View {
        HStack(spacing: 10) {
            quickAction("Entreno libre", "bolt.fill") { startingFreeSession = true }
            quickAction("Generar plan", "wand.and.stars") { showingPlanGenerator = true }
            quickAction("Registrar peso", "scalemass.fill") { loggingWeight = true }
        }
    }

    private func quickAction(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: Fmt.longDay(.now))
            Text("Gimnasio")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.top, 8)
    }

    // MARK: - Hero: anillo semanal

    private var heroCard: some View {
        BezelCard {
            VStack(spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Eyebrow(text: "Esta semana")
                        Text(insightText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                }

                ZStack {
                    ProgressRing(value: ringProgress, tint: ringColor, lineWidth: 16)
                    VStack(spacing: 2) {
                        Text("\(sessionsThisWeek)")
                            .font(.hero(46))
                            .foregroundStyle(Palette.textPrimary)
                            .monospacedDigit()
                        Text("de \(weeklyGoal) sesiones")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                .frame(width: 176, height: 176)
                .frame(maxWidth: .infinity)

                HStack(spacing: 10) {
                    miniStat("\(streak)", "Semanas seguidas", "flame.fill", Palette.record)
                    miniStat(Fmt.volume(weekVolume), "Volumen 7 días", "square.stack.3d.up.fill", Palette.accent)
                    miniStat("\(sessions.count)", "Entrenos totales", "checkmark.seal.fill", Palette.textPrimary)
                }
            }
        }
    }

    private func miniStat(_ value: String, _ label: String, _ symbol: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(tint)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Palette.textTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.04)))
    }

    /// Mensaje corto que se adapta a la situación real: qué toca, si ya has
    /// entrenado hoy, si llevas días sin pisar el gimnasio, etc.
    private var insightText: String {
        if didTrainToday {
            return "Ya has entrenado hoy. Buen trabajo."
        }
        if let routine = todayRoutine {
            return "Hoy toca \(routine.name). Vamos allá."
        }
        if let days = daysSinceLastSession, days >= 4 {
            return "Llevas \(days) días sin entrenar. ¿Retomamos hoy?"
        }
        if sessionsThisWeek >= weeklyGoal, weeklyGoal > 0 {
            return "Objetivo semanal cumplido. Lo de hoy es extra."
        }
        if streak >= 2 {
            return "Llevas \(streak) semanas seguidas. No rompas la racha."
        }
        if sessions.isEmpty {
            return "Apunta tu primer entreno para empezar a ver progreso real."
        }
        return "Sin rutina programada hoy. Un entreno libre también cuenta."
    }

    // MARK: - Marca reciente

    private func recentRecordBanner(_ record: TrainingCalculator.RecentRecord) -> some View {
        HStack(spacing: 12) {
            IconBadge(symbol: "trophy.fill", color: Palette.record, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text("Nueva marca: \(record.exercise.name)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text("\(Fmt.weight(record.weight)) × \(record.reps) · \(Fmt.dayTitle(record.date))")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Palette.record.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).strokeBorder(Palette.record.opacity(0.28), lineWidth: 1))
    }

    // MARK: - Plan de hoy

    private var planCard: some View {
        Group {
            if let routine = todayRoutine {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Eyebrow(text: "Toca hoy")
                        Spacer()
                    }
                    HStack(spacing: 14) {
                        IconBadge(symbol: routine.symbol, color: Color(hex: routine.colorHex), size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(routine.name)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(Palette.textPrimary)
                            Text("\(routine.exercises.count) ejercicios · \(routine.totalSets) series")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    PrimaryActionButton(title: "Empezar entreno", symbol: "play.fill",
                                        tint: Color(hex: routine.colorHex), fullWidth: true) {
                        startingRoutine = routine
                    }
                }
                .card()
            } else if routines.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Eyebrow(text: "Empieza aquí")
                    Text("Todavía no tienes ningún plan")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text("Genera un plan de rutinas según tu objetivo, o entrena libre sin plantilla.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)
                    HStack(spacing: 10) {
                        PrimaryActionButton(title: "Generar plan", symbol: "wand.and.stars") {
                            showingPlanGenerator = true
                        }
                        GhostButton(title: "Entreno libre", symbol: "bolt.fill") {
                            startingFreeSession = true
                        }
                    }
                }
                .card()
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Eyebrow(text: "Hoy")
                    Text("Sin rutina programada")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text("Puedes empezar un entreno libre e ir añadiendo ejercicios sobre la marcha.")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)
                    GhostButton(title: "Entreno libre", symbol: "bolt.fill", tint: Palette.accent) {
                        startingFreeSession = true
                    }
                }
                .card()
            }
        }
    }

    // MARK: - Próximos entrenos

    private var upcomingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Próximos esta semana")
            VStack(spacing: 0) {
                ForEach(Array(upcomingThisWeek.enumerated()), id: \.offset) { index, entry in
                    HStack(spacing: 12) {
                        Text(entry.weekday.short)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Palette.canvas)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color(hex: entry.routine.colorHex)))
                        IconBadge(symbol: entry.routine.symbol, color: Color(hex: entry.routine.colorHex), size: 30)
                        Text(entry.routine.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer(minLength: 0)
                        Text("\(entry.routine.totalSets) series")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    .padding(.vertical, 8)
                    if index < upcomingThisWeek.count - 1 {
                        Divider().overlay(Palette.hairline)
                    }
                }
            }
        }
        .card()
    }

    // MARK: - Peso corporal

    private var bodyWeightCard: some View {
        HStack(spacing: 14) {
            IconBadge(symbol: "scalemass.fill", color: Palette.textPrimary, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text("Peso corporal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                if let last = weightEntries.first {
                    Text("\(Fmt.weight(last.kg)) · \(Fmt.dayTitle(last.date))")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textTertiary)
                } else {
                    Text("Todavía no has apuntado ninguno")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            Spacer(minLength: 0)
            Button { loggingWeight = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Palette.accent.opacity(0.15)))
            }
            .buttonStyle(.plain)
        }
        .card()
    }

    // MARK: - Último entreno

    private func lastSessionCard(_ session: WorkoutSession) -> some View {
        NavigationLink(value: session) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Último entreno")
                HStack(spacing: 12) {
                    IconBadge(symbol: session.routineSymbol, color: Color(hex: session.routineColorHex), size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.routineName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                        Text(Fmt.dayTitle(session.date))
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Fmt.minutes(session.durationSeconds))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Palette.textSecondary)
                        Text(Fmt.volume(session.totalVolume))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tira semanal con estado real (hecho / perdido / programado)

struct WeekProgressStrip: View {
    let routines: [Routine]
    let sessions: [WorkoutSession]

    private let calendar = Calendar.current
    private var todayRaw: Int { Weekday.current().rawValue }

    private func routine(for day: Weekday) -> Routine? {
        routines.first { $0.scheduledDays.contains(day.rawValue) }
    }

    private func done(for day: Weekday) -> Bool {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start,
              let dayDate = calendar.date(byAdding: .day, value: day.rawValue - 1, to: weekStart) else { return false }
        return sessions.contains { calendar.isDate($0.date, inSameDayAs: dayDate) }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases) { day in
                let isToday = day.rawValue == todayRaw
                let isPast = day.rawValue < todayRaw
                let scheduled = routine(for: day)
                let isDone = done(for: day)
                let tint = Color(hex: scheduled?.colorHex ?? "9C9CA6")

                VStack(spacing: 8) {
                    Text(day.short)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isToday ? Palette.textPrimary : Palette.textTertiary)

                    ZStack {
                        if isDone {
                            Circle().fill(Palette.success)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Palette.canvas)
                        } else if scheduled != nil, isPast {
                            Circle().strokeBorder(Palette.textTertiary.opacity(0.4), lineWidth: 1.5)
                        } else if scheduled != nil {
                            Circle().fill(tint)
                        } else {
                            Circle().fill(Palette.textTertiary.opacity(0.25)).frame(width: 8, height: 8)
                        }
                    }
                    .frame(width: 20, height: 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background {
                    if isToday {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    }
                }
            }
        }
        .card(padding: 8)
    }
}
