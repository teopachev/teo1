import WidgetKit
import SwiftUI

/// Anillo de sesiones semanales para la pantalla bloqueada.
struct LockRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LockRingWidget", provider: GymProvider()) { entry in
            LockRingView(snapshot: entry.snapshot)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Sesiones semanales")
        .description("Anillo con las sesiones cumplidas esta semana.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

struct LockRingView: View {
    let snapshot: WidgetSnapshot
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Gauge(value: min(1, snapshot.progress)) {
                    Image(systemName: "dumbbell.fill")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(snapshot.sessionsThisWeek)/\(snapshot.weeklyGoal) sesiones")
                        .font(.system(size: 13, weight: .semibold))
                    if snapshot.streak > 0 {
                        Text("\(snapshot.streak) semanas seguidas")
                            .font(.system(size: 11))
                    }
                }
            }
        default:
            Gauge(value: min(1, snapshot.progress)) {
                Image(systemName: "dumbbell.fill")
            } currentValueLabel: {
                Text("\(snapshot.sessionsThisWeek)")
            }
            .gaugeStyle(.accessoryCircular)
        }
    }
}
