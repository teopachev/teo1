import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Sesión de entrenamiento en directo: aquí es donde se apuntan de verdad los
/// pesos y las reps. Si viene de una rutina, se parte de sus series objetivo
/// (sugiriendo el peso de la última vez); si no, es un entreno libre al que
/// se añaden ejercicios sobre la marcha. Nada se guarda en el historial hasta
/// que confirmas cada serie.
struct ActiveSessionView: View {
    var routine: Routine?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.date, order: .reverse) private var pastSessions: [WorkoutSession]

    @State private var session: WorkoutSession?
    @State private var startDate = Date()
    @State private var now = Date()
    @State private var isResting = false
    @State private var restRemaining = 0
    @State private var restTotal = 0
    @State private var didStart = false
    @State private var showingPicker = false
    @State private var confirmingDiscard = false
    @State private var plateCalcTarget: PlateCalcTarget?
    @State private var prBanner: String?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var accent: Color { Color(hex: session?.routineColorHex ?? "6FA0C8") }
    private var totalSets: Int { session?.exercises.reduce(0) { $0 + $1.sets.count } ?? 0 }
    private var completedCount: Int { session?.completedSets.count ?? 0 }
    private var elapsed: Int { max(0, Int(now.timeIntervalSince(startDate))) }
    private var hasProgress: Bool { completedCount > 0 }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScreenBackground()
            VStack(spacing: 0) {
                topBar
                if let session {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(session.orderedExercises) { item in
                                sessionBlock(item)
                            }
                            addExerciseButton
                            notesField
                        }
                        .padding(.horizontal, Metrics.screenPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 160)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    Spacer()
                }
            }
            if isResting {
                restPanel.transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                finishBar.transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let prBanner {
                prToast(prBanner)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 70)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .sheet(item: $plateCalcTarget) { target in
            PlateCalculatorView(targetWeight: target.weight)
        }
        .onReceive(timer) { _ in
            now = Date()
            guard isResting, restRemaining > 0 else { return }
            restRemaining -= 1
            if restRemaining <= 0 { withAnimation(.smoothSpring) { isResting = false } }
        }
        .onAppear(perform: start)
        .confirmationDialog("¿Descartar este entreno?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Descartar", role: .destructive) { discard() }
            Button("Seguir entrenando", role: .cancel) {}
        } message: {
            Text("Se perderán las series que ya has confirmado.")
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 640)
        #endif
    }

    // MARK: - Arranque

    private func start() {
        guard !didStart else { return }
        didStart = true

        let s = WorkoutSession(
            date: .now,
            routineName: routine?.name.isEmpty == false ? routine!.name : "Entreno libre",
            routineColorHex: routine?.colorHex ?? "6FA0C8",
            routineSymbol: routine?.symbol ?? "bolt.fill",
            routine: routine
        )
        context.insert(s)

        if let routine {
            for planned in routine.orderedExercises {
                addExercise(from: planned, to: s)
            }
        }

        session = s
        startDate = .now
        now = .now
    }

    private func addExercise(from planned: RoutineExercise, to s: WorkoutSession) {
        let item = SessionExercise(
            order: s.exercises.count,
            restSeconds: planned.restSeconds,
            notes: planned.notes,
            exerciseName: planned.exercise?.name ?? "Ejercicio",
            exerciseColorHex: planned.exercise?.colorHex ?? "9C9CA6",
            exerciseSymbol: planned.exercise?.symbol ?? "dumbbell.fill",
            exercise: planned.exercise
        )
        context.insert(item)
        item.session = s

        for target in planned.orderedSets {
            let weight = target.targetWeight > 0 ? target.targetWeight : suggestedWeight(for: planned.exercise)
            let set = LoggedSet(order: target.order, reps: target.targetReps, weight: weight, isWarmup: target.isWarmup)
            context.insert(set)
            set.sessionExercise = item
        }
    }

    private func addFreeExercise(_ exercise: Exercise) {
        guard let session else { return }
        let item = SessionExercise(
            order: session.exercises.count,
            restSeconds: 90,
            exerciseName: exercise.name,
            exerciseColorHex: exercise.colorHex,
            exerciseSymbol: exercise.symbol,
            exercise: exercise
        )
        context.insert(item)
        item.session = session

        let weight = suggestedWeight(for: exercise)
        for i in 0..<3 {
            let set = LoggedSet(order: i, reps: 8, weight: weight, isWarmup: false)
            context.insert(set)
            set.sessionExercise = item
        }
    }

    /// Último peso confirmado de este ejercicio en una sesión anterior, para
    /// no partir siempre de cero al planificar la carga.
    private func suggestedWeight(for exercise: Exercise?) -> Double {
        guard let exercise else { return 0 }
        let history = TrainingCalculator.history(of: exercise, in: pastSessions)
        return history.last(where: { !$0.set.isWarmup })?.set.weight ?? 0
    }

    // MARK: - Barra superior

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                if hasProgress { confirmingDiscard = true } else { discard() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(session?.routineName ?? "Entreno")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text("\(completedCount) de \(totalSets) series")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textTertiary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "stopwatch")
                    .font(.system(size: 13, weight: .semibold))
                Text(Fmt.clock(elapsed))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(accent.opacity(0.14)))
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
        }
    }

    // MARK: - Bloque de ejercicio

    private func sessionBlock(_ item: SessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconBadge(symbol: item.exerciseSymbol, color: Color(hex: item.exerciseColorHex), size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.exerciseName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text("Descanso \(Fmt.restLabel(item.restSeconds))")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer(minLength: 0)
            }
            if !item.notes.isEmpty {
                Text(item.notes)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04)))
            }
            VStack(spacing: 8) {
                ForEach(Array(item.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                    sessionSetRow(set, index: index + 1, rest: item.restSeconds, exercise: item.exercise)
                }
            }
            Button { addSet(to: item) } label: {
                Label("Añadir serie", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .card()
    }

    private func addSet(to item: SessionExercise) {
        let last = item.orderedSets.last
        let set = LoggedSet(order: item.sets.count, reps: last?.reps ?? 8, weight: last?.weight ?? 0, isWarmup: false)
        context.insert(set)
        set.sessionExercise = item
    }

    private var addExerciseButton: some View {
        Button { showingPicker = true } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Añadir ejercicio")
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                    .strokeBorder(Palette.hairlineStrong, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
            )
        }
        .buttonStyle(PressableStyle())
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView { addFreeExercise($0) }
        }
    }

    // MARK: - Fila de serie

    private func sessionSetRow(_ set: LoggedSet, index: Int, rest: Int, exercise: Exercise?) -> some View {
        HStack(spacing: 10) {
            Text(set.isWarmup ? "W" : "\(index)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.textTertiary)
                .frame(width: 18)

            HStack(spacing: 3) {
                TextField("0", value: bindingReps(set), format: .number)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 30)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                Text("reps").font(.system(size: 12)).foregroundStyle(Palette.textTertiary)
            }

            HStack(spacing: 3) {
                TextField("0", value: bindingWeight(set), format: .number)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 44)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Text("kg").font(.system(size: 12)).foregroundStyle(Palette.textTertiary)
            }

            if !set.isBodyweight {
                Button {
                    plateCalcTarget = PlateCalcTarget(weight: set.weight)
                } label: {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textTertiary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Button {
                toggle(set, rest: rest, exercise: exercise)
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(set.isCompleted ? Palette.success : Palette.textTertiary)
            }
            .buttonStyle(.plain)
            .disabled(set.reps <= 0 && !set.isCompleted)
        }
        .foregroundStyle(Palette.textPrimary)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(set.isCompleted ? Palette.success.opacity(0.08) : Color.white.opacity(0.03))
        )
        .keyboardDoneButton()
    }

    private func bindingReps(_ set: LoggedSet) -> Binding<Int> {
        Binding(get: { set.reps }, set: { set.reps = max(0, $0) })
    }

    private func bindingWeight(_ set: LoggedSet) -> Binding<Double> {
        Binding(get: { set.weight }, set: { set.weight = max(0, $0) })
    }

    private func toggle(_ set: LoggedSet, rest: Int, exercise: Exercise?) {
        let wasCompleted = set.isCompleted
        withAnimation(.snappySpring) {
            set.isCompleted.toggle()
            set.completedAt = .now
        }
        guard !wasCompleted, set.isCompleted else { return }

        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif

        if rest > 0 {
            restTotal = rest
            restRemaining = rest
            withAnimation(.smoothSpring) { isResting = true }
        }

        if let exercise, !set.isWarmup {
            let priorSessions = pastSessions.filter { $0.persistentModelID != session?.persistentModelID }
            let priorHistory = TrainingCalculator.history(of: exercise, in: priorSessions)
            if TrainingCalculator.isPersonalRecord(set, priorHistory: priorHistory) {
                celebrate(exercise.name)
            }
        }
    }

    private func celebrate(_ exerciseName: String) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        withAnimation(.smoothSpring) { prBanner = exerciseName }
        Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if prBanner == exerciseName {
                withAnimation(.smoothSpring) { prBanner = nil }
            }
        }
    }

    // MARK: - Barra de finalizar

    private var finishBar: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Palette.hairline).frame(height: 1)
            PrimaryActionButton(
                title: hasProgress ? "Finalizar entreno" : "Finalizar sin series",
                symbol: "flag.checkered",
                tint: hasProgress ? Palette.success : accent,
                fullWidth: true
            ) {
                finish()
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, 14)
            .padding(.bottom, 22)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Panel de descanso

    private var restPanel: some View {
        VStack(spacing: 14) {
            HStack {
                Text("DESCANSO").font(.eyebrow).tracking(2).foregroundStyle(Palette.textTertiary)
                Spacer()
                Button("Saltar") { withAnimation(.smoothSpring) { isResting = false } }
                    .font(.system(size: 14, weight: .semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(accent)
            }
            HStack(spacing: 18) {
                restControl("-15", "minus") { restRemaining = max(0, restRemaining - 15) }
                Text(Fmt.clock(restRemaining))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
                    .frame(minWidth: 130)
                restControl("+15", "plus") {
                    restRemaining += 15
                    restTotal = max(restTotal, restRemaining)
                }
            }
            ThinBar(value: restTotal > 0 ? Double(restRemaining) / Double(restTotal) : 0, tint: accent, height: 6)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 1) }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
        .shadow(color: Color.black.opacity(0.4), radius: 20, y: 10)
    }

    // MARK: - Notas y celebración de PR

    private var notesBinding: Binding<String> {
        Binding(get: { session?.notes ?? "" }, set: { session?.notes = $0 })
    }

    private var notesField: some View {
        FieldBox("Notas", detail: "opcional") {
            TextField("Cómo te has encontrado, técnica…", text: notesBinding, axis: .vertical)
                .font(.system(size: 14))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1...4)
        }
    }

    private func prToast(_ exerciseName: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 15))
                .foregroundStyle(Palette.record)
            VStack(alignment: .leading, spacing: 1) {
                Text("¡Nuevo récord!")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text(exerciseName)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Palette.record.opacity(0.4), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.4), radius: 16, y: 8)
    }

    private func restControl(_ label: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 13, weight: .bold))
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Palette.textSecondary)
            .frame(width: 52, height: 52)
            .background(Circle().fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Acciones finales

    private func finish() {
        guard let session else { dismiss(); return }
        session.durationSeconds = elapsed

        // Las series que no se llegaron a confirmar no forman parte del
        // historial: se descartan para no dejar ceros fantasma en el progreso.
        for item in session.exercises {
            for set in item.sets where !set.isCompleted {
                context.delete(set)
            }
        }
        for item in session.exercises where item.sets.filter(\.isCompleted).isEmpty {
            context.delete(item)
        }

        if session.exercises.isEmpty {
            context.delete(session)
        } else {
            try? context.save()
        }
        dismiss()
    }

    private func discard() {
        if let session { context.delete(session) }
        try? context.save()
        dismiss()
    }
}

private struct PlateCalcTarget: Identifiable {
    let id = UUID()
    let weight: Double
}
