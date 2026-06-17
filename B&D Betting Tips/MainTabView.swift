import SwiftUI

enum AppTab: Hashable {
    case dashboard
    case tips
    case simulator
    case quiz
    case analytics
}

struct MainTabView: View {
    @State private var selection: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selection) {
            DashboardView(selection: $selection)
                .tabItem { Label("Dashboard", systemImage: "house") }
                .tag(AppTab.dashboard)

            TipsView()
                .tabItem { Label("Tips", systemImage: "book") }
                .tag(AppTab.tips)

            SimulatorView()
                .tabItem { Label("Simulator", systemImage: "play.circle") }
                .tag(AppTab.simulator)

            QuizHomeView(selection: $selection)
                .tabItem { Label("Quiz", systemImage: "brain.head.profile") }
                .tag(AppTab.quiz)

            AnalyticsView()
                .tabItem { Label("Analytics", systemImage: "chart.bar") }
                .tag(AppTab.analytics)
        }
        .tint(AppTheme.accent)
        .toolbarBackground(AppTheme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
