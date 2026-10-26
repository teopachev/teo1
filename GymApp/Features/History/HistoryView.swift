import SwiftUI
import SwiftData

/// Historial completo de entrenos realizados, agrupado por mes.
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]

    private enum Mode: String, CaseIterable, Identifiable {
        case list, calendar
        var id: String { rawValue }
        var title: String { self == .list ? "Lista" : "Calendario" }
    }
    @State private var mode: Mode = .list

    private var grouped: [(month: String, items: [WorkoutSession])] {
        var order: [String] = []
        var byMonth: [String: [WorkoutSession]] = [:]
        for session in sessions {
            let key = Fmt.monthYear(session.date)
            if byMonth[key] == nil { order.append(key) }
            byMonth[key, default: []].append(session)
        }
        return order.map { (month: $0, items: byMonth[$0] ?? []) }
    }

    private var weekVolume: Double {
        guard let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) else { return 0 }
        return TrainingCalculator.volume(in: sessions, from: start)
    }

    private var streak: Int { TrainingCalculator.weekStreak(sessions) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionGap) {
                    ScreenTitle(eyebrow: "Registro", title: "Historial")
                        .padding(.top, 8)

                    HStack(spacing: 10) {
                        StatTile(label: "Entrenos", value: "\(sessions.count)", symbol: "checkmark.seal.fill", tint: Palette.accent)
                        StatTile(label: "Semanas seguidas", value: "\(streak)", symbol: "flame.fill", tint: Palette.record)
                        StatTile(label: "Volumen 7 días", value: Fmt.volume(weekVolume), symbol: "square.stack.3d.up.fill")
                    }

                    if sessions.isEmpty {
                        EmptyStateView(symbol: "clock.arrow.circlepath", title: "Sin entrenos todavía",
                                       message: "Cuando termines tu primera sesión, aparecerá aquí.")
                            .card()
                    } else {
                        PillPicker(options: Mode.allCases, selection: $mode, title: { $0.title },
                                   symbol: { $0 == .list ? "list.bullet" : "calendar" })

                        if mode == .calendar {
                            CalendarMonthView(sessions: sessions)
                        } else {
                            ForEach(grouped, id: \.month) { entry in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(entry.month.uppercased())
                                        .font(.system(size: 11, weight: .semibold))
                                        .tracking(1.1)
                                        .foregroundStyle(Palette.textTertiary)
                                    VStack(spacing: 0) {
                                        ForEach(Array(entry.items.enumerated()), id: \.element.persistentModelID) { index, session in
                                            NavigationLink(value: session) {
                                                sessionRow(session)
                                            }
                                            .buttonStyle(.plain)
                                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                Button(role: .destructive) { delete(session) } label: {
                                                    Label("Eliminar", systemImage: "trash")
                                                }
                                            }
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
        }
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        HStack(spacing: 12) {
            IconBadge(symbol: session.routineSymbol, color: Color(hex: session.routineColorHex), size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.routineName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                Text("\(Fmt.weekdayDate(session.date)) · \(session.exercises.count) ejercicios")
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
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .contentShape(Rectangle())
    }

    private func delete(_ session: WorkoutSession) {
        withAnimation(.smoothSpring) {
            context.delete(session)
            try? context.save()
        }
    }
}
