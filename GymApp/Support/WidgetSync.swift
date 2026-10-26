import Foundation
import WidgetKit

/// Mantiene al día la foto que leen los widgets. Se llama cuando cambia algo
/// que ellos enseñan (rutinas, sesiones, objetivo semanal), no en cada
/// respiración.
enum WidgetSync {
    static func refresh(routines: [Routine], sessions: [WorkoutSession], weeklyGoal: Int) {
        let calendar = Calendar.current
        var snapshot = WidgetSnapshot()
        snapshot.updatedAt = .now
        snapshot.weeklyGoal = weeklyGoal

        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        snapshot.sessionsThisWeek = sessions.filter { $0.date >= weekStart }.count
        snapshot.streak = TrainingCalculator.weekStreak(sessions)
        snapshot.totalSessions = sessions.count
        if let start7 = calendar.date(byAdding: .day, value: -7, to: .now) {
            snapshot.weekVolume = TrainingCalculator.volume(in: sessions, from: start7)
        }
        snapshot.didTrainToday = sessions.contains { calendar.isDateInToday($0.date) }

        if let today = routines.first(where: { $0.scheduledDays.contains(Weekday.current().rawValue) }) {
            snapshot.hasRoutineToday = true
            snapshot.todayRoutineName = today.name
            snapshot.todayRoutineSymbol = today.symbol
            snapshot.todayRoutineColorHex = today.colorHex
        }

        if let last = sessions.first {
            snapshot.lastSessionName = last.routineName
            snapshot.lastSessionDate = last.date
        }

        WidgetStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
