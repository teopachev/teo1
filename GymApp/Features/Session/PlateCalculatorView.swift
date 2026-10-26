import SwiftUI

/// Calculadora de discos: cuánto poner en cada lado de la barra para llegar
/// a un peso. Se abre desde el campo de peso de una serie, con ese peso ya
/// puesto, pero se puede ajustar libremente.
struct PlateCalculatorView: View {
    @State private var targetWeight: Double
    @AppStorage("barWeightKg") private var barWeight: Double = 20

    @Environment(\.dismiss) private var dismiss
    @FocusState private var fieldFocused: Bool

    init(targetWeight: Double) {
        _targetWeight = State(initialValue: targetWeight)
    }

    private var breakdown: PlateCalculator.Breakdown {
        PlateCalculator.breakdown(target: targetWeight, barWeight: barWeight)
    }

    private var inexactMessage: String {
        if targetWeight < barWeight {
            return "La barra sola ya pesa \(Fmt.weight(barWeight)), más que el objetivo."
        }
        return "No se llega exacto: quedan \(Fmt.weight(abs(targetWeight - breakdown.reachedWeight))) sin repartir."
    }

    private var plateColor: [Double: Color] = [
        25: Color(hex: "C86F6F"), 20: Color(hex: "6FA0C8"), 15: Color(hex: "C8B36F"),
        10: Color(hex: "6FC8A0"), 5: Color(hex: "E9EBEE"), 2.5: Color(hex: "8A8FC8"),
        1.25: Color(hex: "9C9CA6")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                VStack(spacing: Metrics.sectionGap) {
                    targetField
                    barVisual
                    breakdownCard
                    barWeightRow
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Metrics.screenPadding)
                .padding(.top, 12)
            }
            .navigationTitle("Calculadora de discos")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .keyboardDoneButton()
        }
    }

    private var targetField: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("0", value: $targetWeight, format: .number)
                    .font(.hero(48))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
                    .keyboardType(.decimalPad)
                    .focused($fieldFocused)
                    .frame(width: 140)
                Text("kg").font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.textSecondary)
            }
            if !breakdown.isExact {
                Text(inexactMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.warning)
            }
        }
    }

    private var barVisual: some View {
        HStack(spacing: 3) {
            Spacer(minLength: 0)
            ForEach(Array(expandedPlates.reversed().enumerated()), id: \.offset) { _, weight in
                plateBar(weight)
            }
            Rectangle()
                .fill(Palette.surfaceHi)
                .frame(width: 46, height: 10)
            Text("kg").font(.system(size: 9)).foregroundStyle(Palette.textTertiary).opacity(0)
            Spacer(minLength: 0)
        }
        .frame(height: 110)
        .frame(maxWidth: .infinity)
    }

    private var expandedPlates: [Double] {
        breakdown.plates.sorted { $0.weight < $1.weight }.flatMap { entry in
            Array(repeating: entry.weight, count: entry.count)
        }
    }

    private func plateBar(_ weight: Double) -> some View {
        let height = 40 + min(60, weight * 2.2)
        let width: CGFloat = weight >= 15 ? 16 : 11
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(plateColor[weight] ?? Palette.textSecondary)
            .frame(width: width, height: height)
    }

    private var breakdownCard: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Por lado")
            if breakdown.plates.isEmpty {
                Text("Solo la barra, sin discos.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(breakdown.plates.enumerated()), id: \.offset) { index, entry in
                        HStack {
                            Circle().fill(plateColor[entry.weight] ?? Palette.textSecondary).frame(width: 10, height: 10)
                            Text(Fmt.weight(entry.weight))
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(Palette.textPrimary)
                            Spacer()
                            Text("× \(entry.count)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .padding(.vertical, 8)
                        if index < breakdown.plates.count - 1 {
                            Divider().overlay(Palette.hairline)
                        }
                    }
                }
            }
        }
        .card()
    }

    private var barWeightRow: some View {
        HStack {
            Text("Peso de la barra")
                .font(.system(size: 14))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
            Stepper(value: $barWeight, in: 0...50, step: 2.5) {
                Text(Fmt.weight(barWeight))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
            }
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}
