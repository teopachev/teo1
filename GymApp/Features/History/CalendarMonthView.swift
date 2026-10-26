import SwiftUI
import SwiftData

/// Calendario mensual: un vistazo a qué días has entrenado. Cada día con
/// sesión lleva un punto del color de esa rutina; tocarlo enseña esa sesión.
struct CalendarMonthView: View {
    let sessions: [WorkoutSession]

    @State private var displayedMonth: Date = .now
    @State private var selectedDay: SelectedDay?

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // lunes, para cuadrar con el resto de la app
        return cal
    }

    private var sessionsByDay: [Date: [WorkoutSession]] {
        Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.date) }
    }

    private var gridDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: lastDayOfMonth) else { return [] }
        var days: [Date] = []
        var cursor = firstWeek.start
        while cursor < lastWeek.end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    var body: some View {
        VStack(spacing: 14) {
            monthHeader
            weekdayHeader
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(gridDays, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
        .card()
        .sheet(item: $selectedDay) { day in
            DaySessionsSheet(date: day.date, sessions: day.sessions)
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Palette.surfaceHi))
            }
            .buttonStyle(.plain)

            Spacer()
            Text(Fmt.monthYear(displayedMonth))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
            Spacer()

            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Palette.surfaceHi))
            }
            .buttonStyle(.plain)
            .disabled(calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month))
            .opacity(calendar.isDate(displayedMonth, equalTo: .now, toGranularity: .month) ? 0.3 : 1)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(Weekday.allCases) { day in
                Text(day.short)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let inMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
        let isToday = calendar.isDateInToday(day)
        let daySessions = sessionsByDay[calendar.startOfDay(for: day)] ?? []
        let tint = daySessions.first.map { Color(hex: $0.routineColorHex) } ?? Palette.accent

        return Button {
            guard !daySessions.isEmpty else { return }
            selectedDay = SelectedDay(date: day, sessions: daySessions)
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 13, weight: isToday ? .bold : .regular, design: .rounded))
                    .foregroundStyle(inMonth ? Palette.textPrimary : Palette.textTertiary.opacity(0.5))
                Circle()
                    .fill(daySessions.isEmpty ? Color.clear : tint)
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Circle()
                    .strokeBorder(isToday ? Palette.accent : Color.clear, lineWidth: 1.5)
                    .padding(2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(daySessions.isEmpty)
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return }
        withAnimation(.snappySpring) { displayedMonth = next }
    }
}

private struct SelectedDay: Identifiable {
    var id: Date { date }
    let date: Date
    let sessions: [WorkoutSession]
}

private struct DaySessionsSheet: View {
    let date: Date
    let sessions: [WorkoutSession]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    NavigationLink(value: session) {
                        HStack(spacing: 12) {
                            IconBadge(symbol: session.routineSymbol, color: Color(hex: session.routineColorHex), size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.routineName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Palette.textPrimary)
                                Text("\(Fmt.minutes(session.durationSeconds)) · \(Fmt.volume(session.totalVolume))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.textTertiary)
                            }
                        }
                    }
                }
                .listRowBackground(Palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(ScreenBackground())
            .navigationTitle(Fmt.longDay(date))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: WorkoutSession.self) { SessionDetailView(session: $0) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
