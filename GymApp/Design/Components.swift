import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Fondo de pantalla

/// Lienzo base de la app: grafito con un resplandor superior muy sutil y una
/// viñeta en los bordes para dar profundidad sin ensuciar el monocromo.
struct ScreenBackground: View {
    var body: some View {
        ZStack {
            Palette.canvas
            Palette.ambientGlow
            RadialGradient(
                colors: [Color.clear, Palette.canvasDeep.opacity(0.9)],
                center: .center,
                startRadius: 220,
                endRadius: 720
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Tarjeta de grafito

/// Superficie de tarjeta con gradiente de aluminio, brillo superior de 1px y
/// sombra difusa. Es el contenedor estándar de toda la app.
struct GraphiteCard: ViewModifier {
    var radius: CGFloat = Metrics.cardRadius
    var padding: CGFloat = Metrics.cardPadding

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.cardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.16), Color.white.opacity(0.02), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 12)
    }
}

extension View {
    /// Envuelve la vista en una tarjeta de grafito estándar.
    func card(padding: CGFloat = Metrics.cardPadding, radius: CGFloat = Metrics.cardRadius) -> some View {
        modifier(GraphiteCard(radius: radius, padding: padding))
    }
}

/// Tarjeta de doble bisel para el héroe: un núcleo de cristal montado dentro
/// de una bandeja de aluminio, con curvas concéntricas. Imita hardware físico.
struct BezelCard<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
                    .fill(Palette.cardGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: Metrics.innerRadius, style: .continuous))
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .fill(Palette.bezelGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                    .strokeBorder(Palette.hairlineStrong, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 30, x: 0, y: 22)
    }
}

// MARK: - Etiquetas y cabeceras

/// Micro-etiqueta en versales que precede a un titular.
struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.eyebrow)
            .tracking(1.8)
            .foregroundStyle(Palette.textTertiary)
    }
}

/// Cabecera de sección con título y acción opcional a la derecha.
struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Cabecera grande de pantalla, con eyebrow encima del título.
struct ScreenTitle: View {
    let eyebrow: String
    let title: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: eyebrow)
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
            }
            Spacer()
            if let trailing { trailing }
        }
    }
}

// MARK: - Icono

/// Cuadro redondeado con un SF Symbol teñido.
struct IconBadge: View {
    let symbol: String
    var color: Color = Palette.textSecondary
    var size: CGFloat = 40

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(color.opacity(0.16))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .strokeBorder(color.opacity(0.24), lineWidth: 1)
            )
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(color)
            )
            .frame(width: size, height: size)
    }
}

/// Píldora pequeña con icono y texto, para etiquetas dentro de tarjetas.
struct TagPill: View {
    let text: String
    var color: Color = Palette.textSecondary
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
            }
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.14)))
    }
}

// MARK: - Barras y anillos

/// Barra de progreso fina, con la pista en gris tenue.
struct ThinBar: View {
    var value: Double
    var tint: Color = Palette.accent
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

/// Anillo de progreso al estilo de las apps de salud de Apple.
struct ProgressRing: View {
    var value: Double
    var tint: Color = Palette.accent
    var lineWidth: CGFloat = 14
    var trackOpacity: Double = 0.09

    private var primary: Double { max(0, min(1, value)) }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: primary)
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.55), tint, tint.opacity(0.9)],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .animation(.smoothSpring, value: value)
    }
}

// MARK: - Celdas

/// Cuadrado con una cifra y su etiqueta. Se usan en rejillas de 2 o 3.
struct StatTile: View {
    let label: String
    let value: String
    var detail: String? = nil
    var symbol: String? = nil
    var tint: Color = Palette.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tint.opacity(0.75))
                }
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.figure(19))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
    }
}

/// Fila estándar de lista dentro de una tarjeta.
struct RowCard<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                    .fill(Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                    .strokeBorder(Palette.hairline, lineWidth: 1)
            )
    }
}

// MARK: - Selectores

/// Píldoras de selección única con deslizamiento animado del fondo.
struct PillPicker<T: Hashable & Identifiable>: View {
    let options: [T]
    @Binding var selection: T
    let title: (T) -> String
    var symbol: ((T) -> String)? = nil

    @Namespace private var namespace

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(options) { option in
                    let selected = option == selection
                    Button {
                        withAnimation(.snappySpring) { selection = option }
                    } label: {
                        HStack(spacing: 5) {
                            if let symbol {
                                Image(systemName: symbol(option))
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text(title(option))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(selected ? Color.black : Palette.textSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 13)
                        .background {
                            if selected {
                                Capsule(style: .continuous)
                                    .fill(Palette.accent)
                                    .matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Capsule(style: .continuous).fill(Palette.surface))
            .overlay(Capsule(style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        }
        .scrollClipDisabled()
    }
}

/// Campo de texto con la estética de la app (sin el look de formulario de iOS).
struct FieldBox<Content: View>: View {
    let label: String
    var detail: String? = nil
    private let content: Content

    init(_ label: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.label = label
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(Palette.textTertiary)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
            content
                .padding(.vertical, 11)
                .padding(.horizontal, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                )
        }
    }
}

/// Selector de color en fila de círculos.
struct ColorSwatchPicker: View {
    @Binding var selection: String
    let options: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(options, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle().strokeBorder(.white, lineWidth: selection == hex ? 2.5 : 0)
                        )
                        .onTapGesture { withAnimation(.snappySpring) { selection = hex } }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }
}

/// Selector de SF Symbol en fila de cuadros.
struct SymbolSwatchPicker: View {
    @Binding var selection: String
    let options: [String]
    var tint: Color = Palette.accent

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(options, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selection == symbol ? Palette.canvas : Palette.textSecondary)
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selection == symbol ? tint : Color.white.opacity(0.06))
                        )
                        .onTapGesture { withAnimation(.snappySpring) { selection = symbol } }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }
}

// MARK: - Botones

/// Hunde ligeramente el botón al pulsarlo, simulando una pieza física.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappySpring, value: configuration.isPressed)
    }
}

/// Píldora de acción primaria con icono anidado en su propio círculo.
struct PrimaryActionButton: View {
    let title: String
    var symbol: String = "plus"
    var tint: Color = Palette.accent
    var fullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if fullWidth { Spacer(minLength: 0) }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                ZStack {
                    Circle().fill(Color.black.opacity(0.18))
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .bold))
                }
                .frame(width: 26, height: 26)
                if fullWidth { Spacer(minLength: 0) }
            }
            .foregroundStyle(Color.black)
            .padding(.vertical, 12)
            .padding(.leading, 20)
            .padding(.trailing, 12)
            .background(Capsule().fill(tint))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Botón secundario: contorno fino sobre la superficie.
struct GhostButton: View {
    let title: String
    var symbol: String? = nil
    var tint: Color = Palette.textPrimary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(tint)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Capsule().fill(Palette.surfaceHi))
            .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Control ± compacto para afinar un número (reps o peso) sin teclado.
struct StepperPad: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Palette.surfaceHi))
                .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }
}

#if canImport(UIKit)
extension View {
    /// Botón "Listo" encima del teclado numérico, que en iOS no trae retorno.
    func keyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.accent)
            }
        }
    }
}
#endif

// MARK: - Estado vacío

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Palette.textTertiary)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                GhostButton(title: actionTitle, symbol: "plus", action: action)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: 280)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Hoja estándar

/// Envoltorio para las hojas modales: fondo de la app, título y botones de
/// cerrar y guardar siempre en el mismo sitio.
struct SheetScaffold<Content: View>: View {
    let title: String
    var saveTitle: String = "Guardar"
    var canSave: Bool = true
    var onSave: (() -> Void)? = nil
    private let content: Content

    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        saveTitle: String = "Guardar",
        canSave: Bool = true,
        onSave: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.saveTitle = saveTitle
        self.canSave = canSave
        self.onSave = onSave
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    content
                        .padding(.horizontal, Metrics.screenPadding)
                        .padding(.top, 10)
                        .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.canvas, for: .navigationBar)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .foregroundStyle(Palette.textSecondary)
                }
                if let onSave {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(saveTitle) {
                            onSave()
                            dismiss()
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(canSave ? Palette.accent : Palette.textTertiary)
                        .disabled(!canSave)
                    }
                }
            }
        }
        .presentationBackground(Palette.canvas)
    }
}
