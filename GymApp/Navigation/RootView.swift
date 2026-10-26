import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Pestañas

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case today
    case routines
    case progress
    case history
    case exercises
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:     return "Hoy"
        case .routines:  return "Rutinas"
        case .progress:  return "Progreso"
        case .history:   return "Historial"
        case .exercises: return "Ejercicios"
        case .settings:  return "Ajustes"
        }
    }

    var symbol: String {
        switch self {
        case .today:     return "flame.fill"
        case .routines:  return "list.bullet.rectangle.fill"
        case .progress:  return "chart.xyaxis.line"
        case .history:   return "clock.arrow.circlepath"
        case .exercises: return "dumbbell.fill"
        case .settings:  return "gearshape.fill"
        }
    }
}

// MARK: - Shell adaptativo

/// Decide la disposición según el tamaño: barra flotante en iPhone y sidebar
/// en iPad. La misma base de código para ambos.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var exercises: [Exercise]
    @Query private var routines: [Routine]
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("weeklySessionGoal") private var weeklyGoal: Int = 4

    @State private var tab: AppTab = .today
    @State private var keyboardVisible = false

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        ZStack {
            ScreenBackground()
            layout
        }
        .task {
            Seeder.seedIfNeeded(context, existing: exercises)
            syncWidgets()
        }
        .onChange(of: [routines.count, sessions.count]) { _, _ in syncWidgets() }
        .onChange(of: weeklyGoal) { _, _ in syncWidgets() }
        .sheet(isPresented: .constant(!hasSeenWelcome)) { WelcomeView() }
    }

    private func syncWidgets() {
        WidgetSync.refresh(routines: routines, sessions: sessions, weeklyGoal: weeklyGoal)
    }

    @ViewBuilder
    private var layout: some View {
        #if os(iOS)
        if horizontalSizeClass == .regular {
            splitLayout
        } else {
            tabLayout
        }
        #else
        splitLayout
        #endif
    }

    private var tabLayout: some View {
        screen(for: tab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom) {
                if !keyboardVisible {
                    FloatingTabBar(selection: $tab)
                        .padding(.top, 6)
                        .frame(maxWidth: .infinity)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.snappySpring) { keyboardVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.snappySpring) { keyboardVisible = false }
            }
            #endif
    }

    private var splitLayout: some View {
        NavigationSplitView {
            Sidebar(selection: $tab)
        } detail: {
            ZStack {
                ScreenBackground()
                screen(for: tab)
            }
        }
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .today:     TodayView()
        case .routines:  RoutinesView()
        case .progress:  ProgressDashboardView()
        case .history:   HistoryView()
        case .exercises: ExercisesView()
        case .settings:  SettingsView()
        }
    }
}

// MARK: - Barra flotante (iPhone)

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                let selected = selection == tab
                Button {
                    withAnimation(.snappySpring) { selection = tab }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 15, weight: .semibold))
                        if selected {
                            Text(tab.title)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .foregroundStyle(selected ? Color.black : Palette.textSecondary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, selected ? 12 : 8)
                    .background {
                        if selected {
                            Capsule(style: .continuous)
                                .fill(Palette.accent)
                                .matchedGeometryEffect(id: "tabPill", in: namespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
        .overlay(Capsule(style: .continuous).strokeBorder(Palette.hairlineStrong, lineWidth: 1))
        .clipShape(Capsule(style: .continuous))
        .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: 14)
    }
}

// MARK: - Sidebar (iPad)

struct Sidebar: View {
    @Binding var selection: AppTab

    private var selectionBinding: Binding<AppTab?> {
        Binding(get: { selection }, set: { newValue in
            if let newValue { selection = newValue }
        })
    }

    var body: some View {
        List(selection: selectionBinding) {
            Section {
                ForEach(AppTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.symbol)
                        .tag(tab)
                }
            } header: {
                Text("Gimnasio")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .navigationTitle("Gimnasio")
    }
}
