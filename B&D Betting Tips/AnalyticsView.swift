import Charts
import SwiftData
import SwiftUI

struct AnalyticsView: View {
    @Query private var bets: [VirtualBet]
    @Query(sort: \BankrollEntry.createdAt) private var entries: [BankrollEntry]
    @State private var period = AnalyticsPeriod.week

    private enum AnalyticsPeriod: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case year = "Year"

        var id: String { rawValue }

        var intervalComponent: Calendar.Component {
            switch self {
            case .week: .weekOfYear
            case .month: .month
            case .year: .year
            }
        }

        var bucketComponent: Calendar.Component {
            switch self {
            case .week, .month: .day
            case .year: .month
            }
        }
    }

    private struct BankrollPoint: Identifiable {
        let date: Date
        let balance: Int

        var id: Date { date }
    }

    private struct OutcomeSlice: Identifiable {
        let title: String
        let count: Int
        let color: Color

        var id: String { title }
    }

    private var interval: DateInterval {
        Calendar.current.dateInterval(of: period.intervalComponent, for: .now)
            ?? DateInterval(start: .distantPast, end: .now)
    }

    private var periodBets: [VirtualBet] {
        bets.filter { interval.contains($0.createdAt) }
    }

    private var settledBets: [VirtualBet] {
        bets.filter { bet in
            guard let settledAt = bet.settledAt else { return false }
            return interval.contains(settledAt)
        }
    }

    private var wins: [VirtualBet] {
        settledBets.filter { $0.status == .won }
    }

    private var losses: [VirtualBet] {
        settledBets.filter { $0.status == .lost }
    }

    private var winRate: Double {
        guard !settledBets.isEmpty else { return 0 }
        return Double(wins.count) / Double(settledBets.count) * 100
    }

    private var roi: Double {
        let stake = settledBets.reduce(0) { $0 + $1.stake }
        guard stake > 0 else { return 0 }
        let returns = wins.reduce(0) { $0 + $1.potentialReturn }
        return Double(returns - stake) / Double(stake) * 100
    }

    private var virtualProfit: Int {
        settledBets.reduce(0) { result, bet in
            result + (bet.status == .won ? bet.potentialProfit : -bet.stake)
        }
    }

    private var periodEntries: [BankrollEntry] {
        entries.filter { interval.contains($0.createdAt) }
    }

    private var bankrollPoints: [BankrollPoint] {
        let calendar = Calendar.current
        let balanceBeforePeriod = AppData.startingBalance
            + entries.filter { $0.createdAt < interval.start }.reduce(0) { $0 + $1.amount }

        var points: [BankrollPoint] = []
        var runningBalance = balanceBeforePeriod
        var cursor = interval.start

        while cursor < interval.end {
            let nextDate = calendar.date(byAdding: period.bucketComponent, value: 1, to: cursor)
                ?? interval.end
            runningBalance += entries
                .filter { $0.createdAt >= cursor && $0.createdAt < nextDate }
                .reduce(0) { $0 + $1.amount }
            points.append(BankrollPoint(date: cursor, balance: runningBalance))
            cursor = nextDate
        }

        return points
    }

    private var outcomes: [OutcomeSlice] {
        [
            OutcomeSlice(title: "Won", count: wins.count, color: AppTheme.success),
            OutcomeSlice(title: "Lost", count: losses.count, color: AppTheme.accent)
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Performance Analytics")
                        .font(.title3.bold())
                        .padding(.top, 28)

                    periodPicker

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        metricCard(
                            title: "Total Bets",
                            value: "\(periodBets.count)",
                            icon: "waveform.path.ecg"
                        )
                        metricCard(
                            title: "Win Rate",
                            value: percent(winRate),
                            icon: "chart.line.uptrend.xyaxis"
                        )
                        metricCard(
                            title: "ROI",
                            value: signedPercent(roi),
                            icon: "scope"
                        )
                        metricCard(
                            title: "Virtual Profit",
                            value: signedCoins(virtualProfit),
                            icon: "dollarsign",
                            iconColor: AppTheme.accent
                        )
                    }

                    bankrollChart
                    outcomeChart
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(AnalyticsPeriod.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        period = item
                    }
                } label: {
                    Text(item.rawValue)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(period == item ? AppTheme.accent : Color.clear)
                        .clipShape(Capsule())
                }
                .foregroundStyle(.white)
                .accessibilityAddTraits(period == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func metricCard(
        title: String,
        value: String,
        icon: String,
        iconColor: Color = .white
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(height: 22)

            Text(value)
                .font(.title2)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var bankrollChart: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Bankroll Growth")
                .font(.headline)

            if periodEntries.isEmpty {
                chartEmptyState(
                    icon: "chart.xyaxis.line",
                    title: "No Bankroll Activity",
                    message: "Add and settle virtual bets to see bankroll changes for this period."
                )
            } else {
                Chart(bankrollPoints) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        yStart: .value("Baseline", chartBaseline),
                        yEnd: .value("Balance", point.balance)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.34), Color.blue.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", point.balance)
                    )
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Balance", point.balance)
                    )
                    .foregroundStyle(Color.blue)
                    .symbolSize(46)
                }
                .chartYScale(domain: chartDomain)
                .chartXAxis {
                    AxisMarks(values: xAxisValues) { value in
                        AxisGridLine()
                            .foregroundStyle(AppTheme.border)
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(axisLabel(for: date))
                            }
                        }
                        .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3]))
                            .foregroundStyle(AppTheme.border)
                        AxisValueLabel()
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .frame(height: 210)
                .accessibilityLabel("Bankroll growth chart")
            }
        }
        .padding(20)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var outcomeChart: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Outcome Distribution")
                .font(.headline)

            if settledBets.isEmpty {
                chartEmptyState(
                    icon: "chart.pie",
                    title: "No Settled Bets",
                    message: "Settle a virtual bet as won or lost to see the outcome breakdown."
                )
            } else {
                HStack(spacing: 22) {
                    Chart(outcomes) { outcome in
                        SectorMark(
                            angle: .value("Bets", outcome.count),
                            innerRadius: .ratio(0.62),
                            angularInset: 0
                        )
                        .foregroundStyle(outcome.color)
                    }
                    .frame(width: 160, height: 160)
                    .accessibilityLabel("Bet outcomes: \(wins.count) won and \(losses.count) lost")

                    VStack(alignment: .leading, spacing: 16) {
                        outcomeLegend(outcomes[0])
                        outcomeLegend(outcomes[1])
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 244, alignment: .topLeading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func chartEmptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(.horizontal, 20)
        .background(AppTheme.raised.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func outcomeLegend(_ outcome: OutcomeSlice) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(outcome.color)
                .frame(width: 16, height: 16)

            Text(outcome.title == "Won" ? "Wins" : "Losses")
                .font(.subheadline)
                .foregroundStyle(.white)

            Spacer(minLength: 4)

            Text("\(outcome.count) (\(outcomePercentage(outcome.count))%)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func outcomePercentage(_ count: Int) -> Int {
        guard !settledBets.isEmpty else { return 0 }
        return Int((Double(count) / Double(settledBets.count) * 100).rounded())
    }

    private var chartBaseline: Int {
        let minimum = bankrollPoints.map(\.balance).min() ?? AppData.startingBalance
        let maximum = bankrollPoints.map(\.balance).max() ?? AppData.startingBalance
        let padding = max(50, (maximum - minimum) / 5)
        return minimum - padding
    }

    private var chartDomain: ClosedRange<Int> {
        let minimum = bankrollPoints.map(\.balance).min() ?? AppData.startingBalance
        let maximum = bankrollPoints.map(\.balance).max() ?? AppData.startingBalance
        let padding = max(50, (maximum - minimum) / 5)
        return (minimum - padding)...(maximum + padding)
    }

    private var xAxisValues: AxisMarkValues {
        switch period {
        case .week:
            .stride(by: .day)
        case .month:
            .stride(by: .day, count: 7)
        case .year:
            .stride(by: .month, count: 2)
        }
    }

    private func axisLabel(for date: Date) -> String {
        switch period {
        case .week:
            date.formatted(.dateTime.weekday(.abbreviated))
        case .month:
            date.formatted(.dateTime.day())
        case .year:
            date.formatted(.dateTime.month(.abbreviated))
        }
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1))) + "%"
    }

    private func signedPercent(_ value: Double) -> String {
        "\(value >= 0 ? "+" : "-")\(percent(abs(value)))"
    }

    private func signedCoins(_ value: Int) -> String {
        "\(value >= 0 ? "+" : "-")\(abs(value).formatted())"
    }
}
