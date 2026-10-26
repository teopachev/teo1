import SwiftUI
import SwiftData

/// Selector de ejercicios del catálogo, con buscador y acceso para crear uno
/// nuevo al vuelo. Se usa tanto al montar una rutina como en un entreno libre.
struct ExercisePickerView: View {
    var onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var search = ""
    @State private var creatingExercise = false

    private var filtered: [Exercise] {
        guard !search.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    private var grouped: [(group: MuscleGroup, items: [Exercise])] {
        MuscleGroup.allCases.compactMap { group in
            let items = filtered.filter { $0.muscleGroup == group }
            return items.isEmpty ? nil : (group, items)
        }
    }

    private var favorites: [Exercise] {
        filtered.filter(\.isFavorite)
    }

    var body: some View {
        NavigationStack {
            List {
                if !favorites.isEmpty {
                    Section("Favoritos") {
                        ForEach(favorites) { exercise in exerciseRow(exercise) }
                    }
                    .listRowBackground(Palette.surface)
                }
                ForEach(grouped, id: \.group) { entry in
                    Section(entry.group.title) {
                        ForEach(entry.items) { exercise in exerciseRow(exercise) }
                    }
                    .listRowBackground(Palette.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ScreenBackground())
            .searchable(text: $search, prompt: "Buscar ejercicio")
            .navigationTitle("Añadir ejercicio")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { creatingExercise = true } label: {
                        Label("Nuevo", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .sheet(isPresented: $creatingExercise) {
                ExerciseEditorView { created in
                    onSelect(created)
                    dismiss()
                }
            }
        }
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        Button {
            onSelect(exercise)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: exercise.equipment.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(hex: exercise.colorHex))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(exercise.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                    Text(exercise.equipment.title)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textTertiary)
                }
                Spacer(minLength: 0)
                if exercise.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.record)
                }
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Palette.accent)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Editor para crear o ajustar un ejercicio del catálogo.
struct ExerciseEditorView: View {
    var existing: Exercise?
    var defaultGroup: MuscleGroup? = nil
    var onSave: (Exercise) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var muscleGroup: MuscleGroup = .chest
    @State private var equipment: Equipment = .barbell
    @State private var notes = ""

    var body: some View {
        SheetScaffold(
            title: existing == nil ? "Nuevo ejercicio" : "Editar ejercicio",
            canSave: !name.trimmingCharacters(in: .whitespaces).isEmpty,
            onSave: save
        ) {
            VStack(spacing: Metrics.sectionGap) {
                FieldBox("Nombre") {
                    TextField("P. ej. Press banca", text: $name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("GRUPO MUSCULAR")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Palette.textTertiary)
                    PillPicker(options: MuscleGroup.allCases, selection: $muscleGroup,
                               title: { $0.title }, symbol: { $0.symbol })
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("EQUIPAMIENTO")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Palette.textTertiary)
                    PillPicker(options: Equipment.allCases, selection: $equipment,
                               title: { $0.title }, symbol: { $0.symbol })
                }

                FieldBox("Notas", detail: "opcional") {
                    TextField("Técnica, agarre…", text: $notes, axis: .vertical)
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(2...4)
                }
            }
        }
        .onAppear {
            if let existing {
                name = existing.name
                muscleGroup = existing.muscleGroup
                equipment = existing.equipment
                notes = existing.notes
            } else if let defaultGroup {
                muscleGroup = defaultGroup
            }
        }
    }

    private func save() {
        let clean = name.trimmingCharacters(in: .whitespaces)
        let exercise: Exercise
        if let existing {
            existing.name = clean
            existing.muscleGroup = muscleGroup
            existing.equipment = equipment
            existing.notes = notes
            exercise = existing
        } else {
            exercise = Exercise(name: clean, muscleGroup: muscleGroup, equipment: equipment, notes: notes)
            context.insert(exercise)
        }
        try? context.save()
        onSave(exercise)
    }
}
