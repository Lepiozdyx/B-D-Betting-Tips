import SwiftData
import SwiftUI

struct DashboardView: View {
    @Binding var selection: AppTab
    @Query(sort: \VirtualBet.createdAt, order: .reverse) private var bets: [VirtualBet]
    @Query(sort: \BankrollEntry.createdAt) private var entries: [BankrollEntry]
    @Query(sort: \AppNotice.createdAt, order: .reverse) private var notices: [AppNotice]
    @Environment(\.modelContext) private var modelContext

    @AppStorage("profileDisplayName") private var displayName = "Sports Analyst"
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var showProfile = false
    @State private var showNotifications = false

    private var balance: Int {
        AppData.startingBalance + entries.reduce(0) { $0 + $1.amount }
    }

    private var settledBets: [VirtualBet] {
        bets.filter { $0.status != .pending }
    }

    private var wonBets: [VirtualBet] {
        bets.filter { $0.status == .won }
    }

    private var winRate: Double {
        guard !settledBets.isEmpty else { return 0 }
        return Double(wonBets.count) / Double(settledBets.count) * 100
    }

    private var roi: Double {
        let totalStaked = settledBets.reduce(0) { $0 + $1.stake }
        guard totalStaked > 0 else { return 0 }
        let returns = wonBets.reduce(0) { $0 + $1.potentialReturn }
        return Double(returns - totalStaked) / Double(totalStaked) * 100
    }

    private var unreadCount: Int {
        notices.filter { !$0.isRead }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    Label(
                        "18+ Educational simulator. No real-money betting. Play responsibly.",
                        systemImage: "exclamationmark.circle"
                    )
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppTheme.accent.opacity(0.75))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    AppCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Virtual Bankroll", systemImage: "circle.grid.cross")
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("\(balance.formatted()) B-Coins")
                                .font(.system(size: 36, weight: .medium, design: .rounded))
                                .contentTransition(.numericText())
                            HStack {
                                metric("Total Bets", value: "\(bets.count)")
                                metric("Win Rate", value: winRate.formatted(.number.precision(.fractionLength(1))) + "%")
                                metric("ROI", value: signedPercent(roi))
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        summaryCard("Win Rate", value: winRate.formatted(.number.precision(.fractionLength(1))) + "%", icon: "chart.line.uptrend.xyaxis")
                        summaryCard("ROI", value: signedPercent(roi), icon: "scope")
                        summaryCard("Active", value: "\(bets.filter { $0.status == .pending }.count)", icon: "waveform.path.ecg")
                    }

                    Button {
                        selection = .tips
                    } label: {
                        AppCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Tip of the Day", systemImage: "book")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Strategy")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.accent)
                                Text(dailyTip.title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(dailyTip.detail)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .lineLimit(3)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
            }
            .task {
                seedInitialNoticeIfNeeded()
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Welcome Back")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                Text(displayName)
                    .font(.title2.bold())
            }
            Spacer()
            Button {
                showNotifications = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .frame(width: 44, height: 44)
                    if unreadCount > 0 {
                        Circle()
                            .fill(AppTheme.accent)
                            .frame(width: 9, height: 9)
                    }
                }
            }
            .accessibilityLabel("Notifications, \(unreadCount) unread")

            Button {
                showProfile = true
            } label: {
                DashboardAvatar(initials: initials)
            }
            .accessibilityLabel("Profile")
        }
        .foregroundStyle(.white)
    }

    private var dailyTip: BettingTip {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1
        return AppData.tips[(day - 1) % AppData.tips.count]
    }

    private var initials: String {
        let value = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let letters = value.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? "BD" : letters
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryCard(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
            Text(value)
                .font(.title2)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 17))
    }

    private func signedPercent(_ value: Double) -> String {
        let formatted = abs(value).formatted(.number.precision(.fractionLength(1)))
        return "\(value >= 0 ? "+" : "-")\(formatted)%"
    }

    private func seedInitialNoticeIfNeeded() {
        guard notificationsEnabled, notices.isEmpty else { return }
        modelContext.insert(
            AppNotice(
                title: "New Tip Available",
                message: "Check out today's betting strategy tip on bankroll management.",
                kind: .tip
            )
        )
    }
}

private struct DashboardAvatar: View {
    let initials: String

    var body: some View {
        Text(initials.uppercased())
            .font(.subheadline)
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.accent.opacity(0.95),
                                Color(red: 0.18, green: 0.02, blue: 0.04),
                                AppTheme.surface
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
    }
}
