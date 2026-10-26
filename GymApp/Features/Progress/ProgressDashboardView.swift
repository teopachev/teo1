import SwiftUI
import SwiftData
import Charts

/// Vista general de progreso: volumen semanal, peso corporal, reparto por
/// grupo muscular y las marcas personales más recientes. El sitio para ver
/// de un vistazo si de verdad estás avanzando.
struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var weightEntries: [BodyWeightEntry]

    @State private var loggingWeight = false

    private var weeklyVolume: [(weekStart: Date, volume: Double)] {
        TrainingCalculator.weeklyVolume(sessions, weeks: 8)
    }

    private var muscleDistribution: [(group: MuscleGroup, sets: Int)] {
        guard let start = Calendar.current.date(byAdding: .day, value: -28, to: .now) else { return [] }
        return TrainingCalculator.setsByMuscle(in: sessions, since: start)
    }

    private var recentRecords: [TrainingCalculator.RecentRecord] {
        Array(TrainingCalculator.recentPersonalRecords(exercises: exercises, sessions: sessions, withinDays: 60).prefix(6))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                    ScreenTitle(eyebrow: "Análisis", title: "Progreso")
                        .padding(.top, 8)

                    if sessions.isEmpty {
                        EmptyStateView(symbol: "chart.xyaxis.line", title: "Todavía no hay datos",
                                       message: "Cuando registres algunos entrenos, aquí verás tu volumen, tu reparto por grupo muscular y tus marcas.")
                            .card()
                    } else {
                        volumeCard
                        muscleCard
                    }

                    bodyWeightCard

                    if !recentRecords.isEmpty {
                        recordsCard
                    }
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(ScreenBackground())
            .navigationDestination(for: Exercise.self) { ExerciseDetailView(exercise: $0) }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .sheet(isPresented: $loggingWeight) { LogWeightView() }
        }
    }

    // MARK: - Volumen semanal

    private var volumeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Volumen semanal")
            Chart(weeklyVolume, id: \.weekStart) { point in
                BarMark(x: .value("Semana", point.weekStart, unit: .weekOfYear), y: .value("Volumen", point.volume))
                    .foregroundStyle(Palette.accent.gradient)
                    .cornerRadius(4)
            }
            .frame(height: 140)
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
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
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

    // MARK: - Reparto muscular

    private var muscleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Últimas 4 semanas", actionTitle: nil)
            if muscleDistribution.isEmpty {
                Text("Sin series registradas en este periodo.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
            } else {
                let maxSets = max(muscleDistribution.map(\.sets).max() ?? 1, 1)
                VStack(spacing: 10) {
                    ForEach(muscleDistribution, id: \.group) { entry in
                        HStack(spacing: 10) {
                            Text(entry.group.title)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                                .frame(width: 90, alignment: .leading)
                            ThinBar(value: Double(entry.sets) / Double(maxSets),
                                    tint: Color(hex: entry.group.colorHex), height: 8)
                            Text("\(entry.sets)")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Palette.textTertiary)
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .card()
    }

    // MARK: - Peso corporal

    private var bodyWeightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Peso corporal", actionTitle: "Registrar") {
                loggingWeight = true
            }
            if weightEntries.isEmpty {
                Text("Todavía no has apuntado tu peso.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Fmt.weight(weightEntries[0].kg))
                        .font(.figure(24))
                        .foregroundStyle(Palette.textPrimary)
                    Text(Fmt.dayTitle(weightEntries[0].date))
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textTertiary)
                    Spacer()
                    if weightEntries.count >= 2 {
                        let delta = weightEntries[0].kg - weightEntries[min(29, weightEntries.count - 1)].kg
                        Text(Fmt.signed(delta))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(delta <= 0 ? Palette.success : Palette.textSecondary)
                    }
                }
                if weightEntries.count >= 2 {
                    Chart(Array(weightEntries.prefix(30).reversed()), id: \.persistentModelID) { entry in
                        LineMark(x: .value("Fecha", entry.date), y: .value("Peso", entry.kg))
                            .foregroundStyle(Palette.textPrimary)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            .interpolationMethod(.monotone)
                    }
                    .frame(height: 90)
                    .chartYAxis(.hidden)
                    .chartXAxis(.hidden)
                }
            }
        }
        .card()
    }

    // MARK: - Marcas recientes

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Marcas recientes")
            VStack(spacing: 0) {
                ForEach(Array(recentRecords.enumerated()), id: \.offset) { index, record in
                    NavigationLink(value: record.exercise) {
                        HStack(spacing: 12) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(Palette.record)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(record.exercise.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Palette.textPrimary)
                                Text(Fmt.weekdayDate(record.date))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Palette.textTertiary)
                            }
                            Spacer(minLength: 0)
                            Text("\(Fmt.weight(record.weight)) × \(record.reps)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < recentRecords.count - 1 {
                        Divider().overlay(Palette.hairline)
                    }
                }
            }
        }
        .card(padding: 14)
    }
}

// MARK: - Registrar peso

struct LogWeightView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var entries: [BodyWeightEntry]

    @State private var text = ""
    @FocusState private var focused: Bool

    private func number(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var delta: Double? {
        guard let last = entries.first, number(text) > 0 else { return nil }
        let diff = number(text) - last.kg
        return abs(diff) < 0.05 ? nil : diff
    }

    var body: some View {
        SheetScaffold(title: "Registrar peso", canSave: number(text) > 0, onSave: save) {
            VStack(spacing: Metrics.sectionGap) {
                amountBox
                stepperRow
                if let last = entries.first {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textTertiary)
                        Text("Último registro: \(Fmt.weight(last.kg)) · \(Fmt.dayTitle(last.date))")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear {
            if let last = entries.first { text = Fmt.decimal(last.kg) }
            focused = true
        }
    }

    private var amountBox: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Spacer(minLength: 0)
                TextField("0", text: $text)
                    .font(.hero(52))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focused)
                    .frame(width: 160)
                Text("kg")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 0)
            }
            if let delta {
                Text(Fmt.signed(delta))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(delta < 0 ? Palette.success : Palette.textSecondary)
            }
        }
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous).fill(Palette.surface))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .strokeBorder(focused ? Palette.accent.opacity(0.6) : Palette.hairlineStrong, lineWidth: focused ? 1.6 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .onTapGesture { focused = true }
        .animation(.snappySpring, value: focused)
    }

    private var stepperRow: some View {
        HStack(spacing: 8) {
            stepButton("−1", -1)
            stepButton("−0,1", -0.1)
            stepButton("+0,1", 0.1)
            stepButton("+1", 1)
        }
    }

    private func stepButton(_ label: String, _ amount: Double) -> some View {
        Button {
            let next = max(0, number(text) + amount)
            withAnimation(.snappySpring) {
                text = next == next.rounded() ? Fmt.int(next) : Fmt.decimal(next)
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.textSecondary)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Capsule().fill(Palette.surfaceHi))
                .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    private func save() {
        context.insert(BodyWeightEntry(date: .now, kg: number(text)))
        try? context.save()
    }
}
