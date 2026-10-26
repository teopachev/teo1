import SwiftUI
import SwiftData

/// Detalle de un entreno ya realizado: cada ejercicio con las series tal y
/// como se hicieron. Los valores se pueden corregir a mano si te equivocaste
/// al apuntar algo en el momento.
struct SessionDetailView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false

    private var accent: Color { Color(hex: session.routineColorHex) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                hero
                ForEach(session.orderedExercises) { item in
                    exerciseBlock(item)
                }
                notesCard
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(ScreenBackground())
        .navigationTitle(session.routineName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("¿Eliminar este entreno?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { delete() }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var hero: some View {
        BezelCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    IconBadge(symbol: session.routineSymbol, color: accent, size: 50)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.routineName)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        Text(Fmt.longDay(session.date))
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    miniMetric(Fmt.minutes(session.durationSeconds), "Duración")
                    miniMetric("\(session.totalSets)", "Series")
                    miniMetric(Fmt.volume(session.totalVolume), "Volumen")
                }
            }
        }
    }

    private func miniMetric(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.figure(17)).foregroundStyle(Palette.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(caption).font(.system(size: 11)).foregroundStyle(Palette.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func exerciseBlock(_ item: SessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconBadge(symbol: item.exerciseSymbol, color: Color(hex: item.exerciseColorHex), size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.exerciseName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    if let top = item.topSet {
                        Text("Mejor serie: \(top.reps) × \(Fmt.weight(top.weight))")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            VStack(spacing: 0) {
                ForEach(Array(item.orderedSets.enumerated()), id: \.element.persistentModelID) { index, set in
                    loggedSetRow(set, index: index + 1)
                    if index < item.orderedSets.count - 1 {
                        Divider().overlay(Palette.hairline)
                    }
                }
            }
        }
        .card()
    }

    private func loggedSetRow(_ set: LoggedSet, index: Int) -> some View {
        HStack(spacing: 14) {
            Text(set.isWarmup ? "W" : "\(index)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.textTertiary)
                .frame(width: 22)
            Text(Fmt.reps(set.reps))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
            Text("·").foregroundStyle(Palette.textTertiary)
            Text(set.loadText)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Palette.success)
        }
        .padding(.vertical, 9)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Notas")
            TextField("Sin notas", text: $session.notes, axis: .vertical)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1...6)
        }
        .card()
    }

    private func delete() {
        context.delete(session)
        try? context.save()
        dismiss()
    }
}
