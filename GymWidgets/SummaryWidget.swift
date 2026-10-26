import WidgetKit
import SwiftUI

/// Anillo de sesiones de la semana y el plan de hoy. El widget que miras al
/// salir de casa para saber si te toca pasar por el gimnasio.
struct SummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SummaryWidget", provider: GymProvider()) { entry in
            SummaryWidgetView(snapshot: entry.snapshot)
                .containerBackground(W.canvas, for: .widget)
        }
        .configurationDisplayName("Progreso semanal")
        .description("Sesiones cumplidas esta semana y qué toca hoy.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SummaryWidgetView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    private var ringTint: Color { snapshot.progress >= 1 ? W.record : W.accent }

    var body: some View {
        if family == .systemSmall { small } else { medium }
    }

    private var small: some View {
        VStack(spacing: 8) {
            ZStack {
                WidgetRing(value: snapshot.progress, tint: ringTint, lineWidth: 8)
                VStack(spacing: 0) {
                    Text("\(snapshot.sessionsThisWeek)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(W.text)
                    Text("de \(snapshot.weeklyGoal)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(W.dim)
                }
            }
            if snapshot.streak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.system(size: 10)).foregroundStyle(W.record)
                    Text("\(snapshot.streak) sem.").font(.system(size: 11, weight: .semibold)).foregroundStyle(W.dim)
                }
            } else {
                Text("Sesiones/semana").font(.system(size: 10, weight: .medium)).foregroundStyle(W.faint)
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            ZStack {
                WidgetRing(value: snapshot.progress, tint: ringTint, lineWidth: 9)
                VStack(spacing: 0) {
                    Text("\(snapshot.sessionsThisWeek)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(W.text)
                    Text("de \(snapshot.weeklyGoal)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(W.dim)
                }
            }
            .frame(width: 86, height: 86)

            VStack(alignment: .leading, spacing: 8) {
                Text("HOY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(W.faint)

                if snapshot.hasRoutineToday {
                    HStack(spacing: 6) {
                        Image(systemName: snapshot.todayRoutineSymbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(widgetHex: snapshot.todayRoutineColorHex))
                        Text(snapshot.todayRoutineName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(W.text)
                            .lineLimit(1)
                    }
                } else {
                    Text(snapshot.didTrainToday ? "Ya has entrenado" : "Sin rutina programada")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(W.dim)
                        .lineLimit(1)
                }

                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)

                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.system(size: 10)).foregroundStyle(W.record)
                    Text(snapshot.streak > 0 ? "\(snapshot.streak) semanas seguidas" : "Racha por empezar")
                        .font(.system(size: 11))
                        .foregroundStyle(W.dim)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
