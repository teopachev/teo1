import SwiftUI
import SwiftData

/// Asistente de 5 pasos que genera un plan de rutinas completo a partir de un
/// objetivo (volumen, fuerza, definición, cardio), unos días por semana, cómo
/// repartirlos (torso/pierna, empuje/tirón/pierna...) y un nivel. Al
/// confirmar, crea de verdad las `Routine` en SwiftData.
struct PlanGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query private var routines: [Routine]

    private static let totalSteps = 5

    @State private var step = 0
    @State private var goal: TrainingGoal = .hypertrophy
    @State private var days = 4
    @State private var family: PlanGenerator.SplitFamily = .upperLower
    @State private var composition: [PlanGenerator.DayKind: Int] = PlanGenerator.SplitFamily.upperLower.defaultComposition(days: 4)
    @State private var level: ExperienceLevel = .intermediate
    @State private var seed = 0
    @State private var replaceExisting = false

    private var plan: PlanGenerator.GeneratedPlan {
        PlanGenerator.generate(goal: goal, daysPerWeek: days, family: family, composition: composition,
                                level: level, catalog: exercises, seed: seed)
    }

    private var accent: Color { Color(hex: goal.colorHex) }

    private var compositionTotal: Int { composition.values.reduce(0, +) }
    private var compositionValid: Bool { family == .fullBody || compositionTotal == days }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                VStack(spacing: 0) {
                    progressDots
                    ScrollView {
                        Group {
                            switch step {
                            case 0: goalStep
                            case 1: daysStep
                            case 2: splitStep
                            case 3: levelStep
                            default: previewStep
                            }
                        }
                        .padding(.horizontal, Metrics.screenPadding)
                        .padding(.top, 16)
                        .padding(.bottom, 140)
                    }
                    .scrollIndicators(.hidden)
                }
                VStack {
                    Spacer()
                    bottomBar
                }
            }
            .navigationTitle("Generar plan")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .onChange(of: days) { _, _ in resetComposition() }
            .onChange(of: family) { _, _ in resetComposition() }
        }
    }

    /// Vuelve al reparto equilibrado por defecto para la familia y los días
    /// actuales. Se llama al cambiar cualquiera de los dos, que es cuando el
    /// reparto anterior deja de tener sentido.
    private func resetComposition() {
        composition = family.defaultComposition(days: days)
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<Self.totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? accent : Palette.hairlineStrong)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.top, 10)
    }

    // MARK: - Paso 1: objetivo

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionGap) {
            ScreenTitle(eyebrow: "Paso 1 de \(Self.totalSteps)", title: "¿Cuál es tu objetivo?")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(TrainingGoal.allCases) { option in
                    goalCard(option)
                }
            }
        }
    }

    private func goalCard(_ option: TrainingGoal) -> some View {
        let selected = goal == option
        return Button {
            withAnimation(.snappySpring) { goal = option }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                IconBadge(symbol: option.symbol, color: Color(hex: option.colorHex), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(option.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                    .fill(selected ? Color(hex: option.colorHex).opacity(0.16) : Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                    .strokeBorder(selected ? Color(hex: option.colorHex) : Palette.hairline, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Paso 2: días

    private var daysStep: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionGap) {
            ScreenTitle(eyebrow: "Paso 2 de \(Self.totalSteps)", title: "¿Cuántos días a la semana?")
            HStack(spacing: 8) {
                ForEach(2...6, id: \.self) { n in
                    let selected = days == n
                    Button {
                        withAnimation(.snappySpring) { days = n }
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(selected ? Palette.canvas : Palette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(selected ? accent : Palette.surface)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Palette.hairline, lineWidth: selected ? 0 : 1)
                            )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            if goal == .cardio {
                Text("\(days) sesiones de cardio a la semana, variando intensidad.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Palette.surface))
            }
        }
    }

    // MARK: - Paso 3: reparto

    private var splitStep: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionGap) {
            ScreenTitle(eyebrow: "Paso 3 de \(Self.totalSteps)", title: "¿Cómo repartimos los días?")

            if goal == .cardio {
                Text("El cardio no se reparte por grupo muscular: se generarán \(days) sesiones variadas (continuo, intervalos y cardio + core).")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Palette.surface))
            } else {
                VStack(spacing: 10) {
                    ForEach(PlanGenerator.SplitFamily.allCases) { option in
                        familyRow(option)
                    }
                }

                if family != .fullBody {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Días de cada tipo")
                        VStack(spacing: 10) {
                            ForEach(family.kinds) { kind in
                                compositionRow(kind)
                            }
                        }
                        HStack {
                            Text("Total")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                            Spacer()
                            Text("\(compositionTotal) de \(days) días")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(compositionValid ? Palette.success : Palette.warning)
                        }
                    }
                    .card()
                }
            }
        }
    }

    private func familyRow(_ option: PlanGenerator.SplitFamily) -> some View {
        let selected = family == option
        return Button {
            withAnimation(.snappySpring) { family = option }
        } label: {
            HStack(spacing: 12) {
                IconBadge(symbol: option.symbol, color: accent, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                    Text(option.detail).font(.system(size: 12)).foregroundStyle(Palette.textTertiary)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(selected ? accent : Palette.textTertiary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(selected ? Palette.surfaceHi : Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).strokeBorder(selected ? accent.opacity(0.5) : Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private func compositionRow(_ kind: PlanGenerator.DayKind) -> some View {
        HStack {
            Text(kind.title)
                .font(.system(size: 14))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            Stepper(value: compositionBinding(kind), in: 0...days) {
                Text("\(composition[kind] ?? 0) días")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
                    .frame(minWidth: 56, alignment: .trailing)
            }
            .fixedSize()
        }
    }

    private func compositionBinding(_ kind: PlanGenerator.DayKind) -> Binding<Int> {
        Binding(get: { composition[kind] ?? 0 }, set: { composition[kind] = $0 })
    }

    // MARK: - Paso 4: nivel

    private var levelStep: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionGap) {
            ScreenTitle(eyebrow: "Paso 4 de \(Self.totalSteps)", title: "¿Cuál es tu nivel?")
            VStack(spacing: 10) {
                ForEach(ExperienceLevel.allCases) { option in
                    levelRow(option)
                }
            }
        }
    }

    private func levelRow(_ option: ExperienceLevel) -> some View {
        let selected = level == option
        return Button {
            withAnimation(.snappySpring) { level = option }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().strokeBorder(selected ? accent : Palette.hairlineStrong, lineWidth: 1.5)
                    if selected { Circle().fill(accent).frame(width: 10, height: 10) }
                }
                .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.textPrimary)
                    Text(option.detail).font(.system(size: 12)).foregroundStyle(Palette.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(selected ? Palette.surfaceHi : Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Paso 5: previsualización

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionGap) {
            HStack(alignment: .bottom) {
                ScreenTitle(eyebrow: "Paso 5 de \(Self.totalSteps)", title: "Tu plan")
                Spacer()
                Button { seed += 1 } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(accent.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }

            if exercises.isEmpty {
                EmptyStateView(symbol: "exclamationmark.triangle", title: "Sin ejercicios en el catálogo",
                               message: "Añade ejercicios en la pestaña Ejercicios antes de generar un plan.")
                    .card()
            } else {
                ForEach(plan.days) { day in
                    dayCard(day)
                }

                if !routines.isEmpty {
                    Toggle(isOn: $replaceExisting) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sustituir mis rutinas actuales")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Palette.textPrimary)
                            Text("Si lo desactivas, el plan se añade junto a las que ya tienes.")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.textTertiary)
                        }
                    }
                    .tint(accent)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).fill(Palette.surface))
                }
            }
        }
    }

    private func dayCard(_ day: PlanGenerator.GeneratedDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconBadge(symbol: day.symbol, color: Color(hex: day.colorHex), size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text(day.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                    Text(day.detail).font(.system(size: 12)).foregroundStyle(Palette.textTertiary)
                }
                Spacer(minLength: 0)
                if let weekday = day.scheduledDays.first.flatMap(Weekday.init) {
                    TagPill(text: weekday.title, color: Color(hex: day.colorHex))
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(day.exercises.enumerated()), id: \.element.id) { index, item in
                    HStack {
                        Text(item.exercise.name)
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(item.note.isEmpty ? "\(item.sets) × \(item.reps)" : "Cardio")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    .padding(.vertical, 6)
                    if index < day.exercises.count - 1 {
                        Divider().overlay(Palette.hairline)
                    }
                }
            }
        }
        .card()
    }

    // MARK: - Barra inferior

    private var canContinue: Bool {
        step != 2 || goal == .cardio || compositionValid
    }

    private var bottomBar: some View {
        let lastStep = Self.totalSteps - 1
        return VStack(spacing: 0) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
            HStack(spacing: 10) {
                if step > 0 {
                    GhostButton(title: "Atrás") {
                        withAnimation(.snappySpring) { step -= 1 }
                    }
                }
                PrimaryActionButton(title: step < lastStep ? "Continuar" : "Crear plan",
                                    symbol: step < lastStep ? "arrow.right" : "checkmark",
                                    tint: accent, fullWidth: true) {
                    if step < lastStep {
                        withAnimation(.snappySpring) { step += 1 }
                    } else {
                        createPlan()
                    }
                }
                .disabled(step == lastStep ? exercises.isEmpty : !canContinue)
                .opacity((step == lastStep ? exercises.isEmpty : !canContinue) ? 0.5 : 1)
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, 14)
            .padding(.bottom, 22)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Crear de verdad

    private func createPlan() {
        if replaceExisting {
            for routine in routines { context.delete(routine) }
        }
        for day in plan.days {
            let routine = Routine(name: day.name, detail: day.detail, colorHex: day.colorHex,
                                   symbol: day.symbol, scheduledDays: day.scheduledDays)
            context.insert(routine)
            for (order, item) in day.exercises.enumerated() {
                let routineExercise = RoutineExercise(order: order, restSeconds: item.restSeconds,
                                                        notes: item.note, exercise: item.exercise)
                context.insert(routineExercise)
                routineExercise.routine = routine
                for setIndex in 0..<item.sets {
                    let set = RoutineSet(order: setIndex, targetReps: item.reps, targetWeight: 0)
                    context.insert(set)
                    set.routineExercise = routineExercise
                }
            }
        }
        try? context.save()
        dismiss()
    }
}
