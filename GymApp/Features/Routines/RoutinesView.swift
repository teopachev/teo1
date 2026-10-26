import SwiftUI
import SwiftData

/// Lista de rutinas (plantillas) con la tira semanal de qué toca cada día.
struct RoutinesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.createdAt) private var routines: [Routine]

    @State private var draftRoutine: Routine?
    @State private var showingPlanGenerator = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                    ScreenTitle(eyebrow: "Plantillas", title: "Rutinas", trailing: AnyView(addButton))
                        .padding(.top, 8)

                    generateButton
                    WeekStrip(routines: routines)

                    if routines.isEmpty {
                        EmptyStateView(symbol: "list.bullet.rectangle", title: "Sin rutinas",
                                       message: "Genera un plan según tu objetivo, o crea tu primera rutina a mano.",
                                       actionTitle: "Crear a mano") {
                            startNewRoutine()
                        }
                            .card()
                    } else {
                        VStack(spacing: 14) {
                            ForEach(routines) { routine in
                                NavigationLink(value: routine) {
                                    RoutineCard(routine: routine)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button { duplicate(routine) } label: {
                                        Label("Duplicar", systemImage: "plus.square.on.square")
                                    }
                                    Button(role: .destructive) { delete(routine) } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(ScreenBackground())
            .navigationDestination(for: Routine.self) { RoutineDetailView(routine: $0) }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .sheet(item: $draftRoutine) { RoutineEditorView(routine: $0, isNew: true) }
            .sheet(isPresented: $showingPlanGenerator) { PlanGeneratorView() }
        }
    }

    private var generateButton: some View {
        Button { showingPlanGenerator = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Palette.accent.opacity(0.16)).frame(width: 38, height: 38)
                    Image(systemName: "wand.and.stars").font(.system(size: 15)).foregroundStyle(Palette.accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Generar plan").font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                    Text("Volumen, fuerza, definición o cardio").font(.system(size: 12)).foregroundStyle(Palette.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.textTertiary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Palette.cardGradient))
            .overlay(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).strokeBorder(Palette.hairlineStrong, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private var addButton: some View {
        Button { startNewRoutine() } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.accent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Palette.accent.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    private func startNewRoutine() {
        let routine = Routine(name: "", detail: "")
        context.insert(routine)
        draftRoutine = routine
    }

    private func delete(_ routine: Routine) {
        withAnimation(.smoothSpring) {
            context.delete(routine)
            try? context.save()
        }
    }

    /// Copia completa de la rutina (ejercicios y series incluidos), sin días
    /// programados para no chocar con el original en la tira semanal.
    private func duplicate(_ routine: Routine) {
        let copy = Routine(name: "\(routine.name) (copia)", detail: routine.detail,
                            colorHex: routine.colorHex, symbol: routine.symbol, scheduledDays: [])
        context.insert(copy)
        for item in routine.orderedExercises {
            let itemCopy = RoutineExercise(order: item.order, restSeconds: item.restSeconds,
                                            notes: item.notes, exercise: item.exercise)
            context.insert(itemCopy)
            itemCopy.routine = copy
            for set in item.orderedSets {
                let setCopy = RoutineSet(order: set.order, targetReps: set.targetReps,
                                          targetWeight: set.targetWeight, isWarmup: set.isWarmup)
                context.insert(setCopy)
                setCopy.routineExercise = itemCopy
            }
        }
        try? context.save()
    }
}

// MARK: - Tarjeta de rutina

struct RoutineCard: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                IconBadge(symbol: routine.symbol, color: Color(hex: routine.colorHex), size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(routine.name.isEmpty ? "Rutina" : routine.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(routine.detail.isEmpty ? "\(routine.exercises.count) ejercicios" : routine.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
            }

            HStack(spacing: 8) {
                TagPill(text: "\(routine.exercises.count) ejercicios", color: Palette.textSecondary, symbol: "list.bullet")
                TagPill(text: "\(routine.totalSets) series", color: Color(hex: routine.colorHex), symbol: "square.stack.3d.up.fill")
                TagPill(text: Fmt.minutes(routine.estimatedMinutes * 60), color: Palette.textSecondary, symbol: "clock.fill")
            }

            if !routine.scheduledWeekdays.isEmpty {
                HStack(spacing: 6) {
                    ForEach(routine.scheduledWeekdays) { day in
                        Text(day.short)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.canvas)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color(hex: routine.colorHex).opacity(0.85)))
                    }
                }
            }
        }
        .card()
    }
}

// MARK: - Tira semanal

struct WeekStrip: View {
    let routines: [Routine]

    private var todayRaw: Int { Weekday.current().rawValue }

    private func routine(for day: Weekday) -> Routine? {
        routines.first { $0.scheduledDays.contains(day.rawValue) }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases) { day in
                let match = routine(for: day)
                let isToday = day.rawValue == todayRaw
                VStack(spacing: 8) {
                    Text(day.short)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isToday ? Palette.textPrimary : Palette.textTertiary)
                    Circle()
                        .fill(match != nil ? Color(hex: match!.colorHex) : Palette.textTertiary.opacity(0.25))
                        .frame(width: 8, height: 8)
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
