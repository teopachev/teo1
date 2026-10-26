import SwiftUI
import SwiftData

/// Catálogo de ejercicios agrupado por grupo muscular. Desde aquí se llega
/// al progreso histórico de cada uno.
struct ExercisesView: View {
    @Environment(\.modelContext) private var context
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
                .sorted { $0.name < $1.name }
            return items.isEmpty ? nil : (group, items)
        }
    }

    private var favorites: [Exercise] {
        filtered.filter(\.isFavorite).sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Metrics.sectionGap, pinnedViews: []) {
                    ScreenTitle(eyebrow: "Catálogo", title: "Ejercicios", trailing: AnyView(addButton))
                        .padding(.top, 8)

                    if grouped.isEmpty {
                        EmptyStateView(symbol: "dumbbell", title: "Sin ejercicios",
                                       message: "Crea el primero para poder añadirlo a tus rutinas.")
                            .card()
                    } else {
                        if !favorites.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Palette.record)
                                    Text("Favoritos")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Palette.textPrimary)
                                }
                                VStack(spacing: 0) {
                                    ForEach(Array(favorites.enumerated()), id: \.element.persistentModelID) { index, exercise in
                                        exerciseRow(exercise)
                                        if index < favorites.count - 1 {
                                            Divider().overlay(Palette.hairline)
                                        }
                                    }
                                }
                                .card(padding: 6)
                            }
                        }
                        ForEach(grouped, id: \.group) { entry in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Circle().fill(Color(hex: entry.group.colorHex)).frame(width: 7, height: 7)
                                    Text(entry.group.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Palette.textPrimary)
                                    Text("\(entry.items.count)")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(Palette.textTertiary)
                                }
                                VStack(spacing: 0) {
                                    ForEach(Array(entry.items.enumerated()), id: \.element.persistentModelID) { index, exercise in
                                        exerciseRow(exercise)
                                        if index < entry.items.count - 1 {
                                            Divider().overlay(Palette.hairline)
                                        }
                                    }
                                }
                                .card(padding: 6)
                            }
                        }
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(ScreenBackground())
            .searchable(text: $search, prompt: "Buscar ejercicio")
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .sheet(isPresented: $creatingExercise) { ExerciseEditorView() }
        }
    }

    private var addButton: some View {
        Button { creatingExercise = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.accent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Palette.accent.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack(spacing: 10) {
            NavigationLink(value: exercise) {
                HStack(spacing: 12) {
                    IconBadge(symbol: exercise.symbol, color: Color(hex: exercise.colorHex), size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                        Text(exercise.equipment.title)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.snappySpring) { exercise.isFavorite.toggle() }
            } label: {
                Image(systemName: exercise.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(exercise.isFavorite ? Palette.record : Palette.textTertiary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
    }
}
