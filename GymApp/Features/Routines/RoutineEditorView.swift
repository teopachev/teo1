import SwiftUI
import SwiftData

/// Editor de una rutina: nombre, color, icono, días programados y los
/// ejercicios que la componen, con sus series objetivo.
struct RoutineEditorView: View {
    @Bindable var routine: Routine
    let isNew: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showingPicker = false

    private let colorOptions = ["6FA0C8", "6FC8A0", "C8956F", "C88A8A",
                                 "8A8FC8", "C86FA0", "C8B36F", "9C9CA6"]
    private let symbolOptions = ["figure.strengthtraining.traditional",
                                  "figure.strengthtraining.functional",
                                  "figure.cross.training", "dumbbell.fill",
                                  "figure.run", "figure.core.training",
                                  "figure.arms.open", "bolt.heart.fill"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Detalles") {
                    TextField("Nombre (p. ej. Empuje)", text: $routine.name)
                    TextField("Descripción (p. ej. Pecho · Hombro)", text: $routine.detail)
                }
                .listRowBackground(Palette.surface)

                Section("Color") {
                    ColorSwatchPicker(selection: $routine.colorHex, options: colorOptions)
                }
                .listRowBackground(Palette.surface)

                Section("Icono") {
                    SymbolSwatchPicker(selection: $routine.symbol, options: symbolOptions,
                                       tint: Color(hex: routine.colorHex))
                }
                .listRowBackground(Palette.surface)

                Section("Días programados") {
                    HStack(spacing: 8) {
                        ForEach(Weekday.allCases) { day in
                            let active = routine.scheduledDays.contains(day.rawValue)
                            Text(day.short)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(active ? Palette.canvas : Palette.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(active ? Color(hex: routine.colorHex) : Color.white.opacity(0.06))
                                )
                                .onTapGesture { toggleDay(day) }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(Palette.surface)

                Section("Ejercicios") {
                    if routine.orderedExercises.isEmpty {
                        Text("Aún no hay ejercicios. Añade el primero.")
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    ForEach(routine.orderedExercises) { item in
                        NavigationLink(value: item) {
                            HStack(spacing: 12) {
                                Image(systemName: item.exercise?.symbol ?? "dumbbell.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(hex: item.exercise?.colorHex ?? "9C9CA6"))
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.exercise?.name ?? "Ejercicio")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Palette.textPrimary)
                                    Text(item.schemeSummary)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Palette.textTertiary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteExercises)
                    .onMove(perform: moveExercises)

                    Button { showingPicker = true } label: {
                        Label("Añadir ejercicio", systemImage: "plus.circle.fill")
                            .foregroundStyle(Palette.accent)
                    }
                }
                .listRowBackground(Palette.surface)
            }
            .navigationTitle(isNew ? "Nueva rutina" : "Editar rutina")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .scrollContentBackground(.hidden)
            .background(ScreenBackground())
            .navigationDestination(for: RoutineExercise.self) { RoutineExerciseEditorView(item: $0) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { save() }
                        .fontWeight(.semibold)
                        .disabled(routine.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView { add($0) }
            }
        }
    }

    // MARK: - Acciones

    private func toggleDay(_ day: Weekday) {
        if let idx = routine.scheduledDays.firstIndex(of: day.rawValue) {
            routine.scheduledDays.remove(at: idx)
        } else {
            routine.scheduledDays.append(day.rawValue)
        }
    }

    private func add(_ exercise: Exercise) {
        let item = RoutineExercise(order: routine.exercises.count, restSeconds: 90, exercise: exercise)
        context.insert(item)
        item.routine = routine
        for s in 0..<3 {
            let set = RoutineSet(order: s, targetReps: 10, targetWeight: 0)
            context.insert(set)
            set.routineExercise = item
        }
    }

    private func deleteExercises(_ offsets: IndexSet) {
        let ordered = routine.orderedExercises
        for index in offsets { context.delete(ordered[index]) }
        reindex()
    }

    private func moveExercises(_ offsets: IndexSet, _ destination: Int) {
        var ordered = routine.orderedExercises
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, item) in ordered.enumerated() { item.order = index }
    }

    private func reindex() {
        for (index, item) in routine.orderedExercises.enumerated() { item.order = index }
    }

    private func save() {
        routine.name = routine.name.trimmingCharacters(in: .whitespaces)
        try? context.save()
        dismiss()
    }

    private func cancel() {
        if isNew { context.delete(routine) }
        try? context.save()
        dismiss()
    }
}

// MARK: - Editor de un ejercicio dentro de la rutina

struct RoutineExerciseEditorView: View {
    @Bindable var item: RoutineExercise
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section("Descanso entre series") {
                Stepper(value: $item.restSeconds, in: 0...360, step: 15) {
                    HStack {
                        Text("Descanso")
                        Spacer()
                        Text(Fmt.restLabel(item.restSeconds)).foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            .listRowBackground(Palette.surface)

            Section("Series") {
                ForEach(Array(item.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                    RoutineSetEditRow(set: set, index: index + 1)
                }
                .onDelete(perform: deleteSets)

                Button { addSet() } label: {
                    Label("Añadir serie", systemImage: "plus.circle.fill")
                        .foregroundStyle(Palette.accent)
                }
            }
            .listRowBackground(Palette.surface)

            Section("Notas") {
                TextField("Técnica, cadencia…", text: $item.notes, axis: .vertical)
            }
            .listRowBackground(Palette.surface)
        }
        .navigationTitle(item.exercise?.name ?? "Ejercicio")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .scrollContentBackground(.hidden)
        .background(ScreenBackground())
    }

    private func addSet() {
        let last = item.orderedSets.last
        let set = RoutineSet(order: item.sets.count,
                              targetReps: last?.targetReps ?? 10,
                              targetWeight: last?.targetWeight ?? 0)
        context.insert(set)
        set.routineExercise = item
    }

    private func deleteSets(_ offsets: IndexSet) {
        let ordered = item.orderedSets
        for index in offsets { context.delete(ordered[index]) }
        for (i, set) in item.orderedSets.enumerated() { set.order = i }
    }
}

// MARK: - Fila editable de serie objetivo

struct RoutineSetEditRow: View {
    @Bindable var set: RoutineSet
    let index: Int

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(set.isWarmup ? "Calentamiento" : "Serie \(index)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Toggle("", isOn: $set.isWarmup).labelsHidden()
            }
            HStack(spacing: 16) {
                Stepper(value: $set.targetReps, in: 1...50) {
                    Text(Fmt.reps(set.targetReps))
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                }
                HStack(spacing: 6) {
                    Text(set.isBodyweight ? "Lastre" : "Peso")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textTertiary)
                    TextField("0", value: $set.targetWeight, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 52)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Text("kg").foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
