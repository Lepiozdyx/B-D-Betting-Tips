import SwiftData
import SwiftUI

struct SimulatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VirtualBet.createdAt, order: .reverse) private var bets: [VirtualBet]
    @Query(sort: \BankrollEntry.createdAt) private var entries: [BankrollEntry]
    @State private var showAddBet = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    private var balance: Int {
        AppData.startingBalance + entries.reduce(0) { $0 + $1.amount }
    }

    private var activeBets: [VirtualBet] {
        bets.filter { $0.status == .pending }
    }

    private var settledBets: [VirtualBet] {
        bets.filter { $0.status != .pending }
    }

    private var wonBets: [VirtualBet] {
        settledBets.filter { $0.status == .won }
    }

    private var roi: Double {
        let totalStaked = settledBets.reduce(0) { $0 + $1.stake }
        guard totalStaked > 0 else { return 0 }
        let returns = wonBets.reduce(0) { $0 + $1.potentialReturn }
        return Double(returns - totalStaked) / Double(totalStaked) * 100
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Bet Simulator")
                            .font(.title3.bold())
                            .padding(.top, 18)

                        HStack(spacing: 12) {
                            metricCard("Open Bets", value: "\(activeBets.count)", icon: "waveform.path.ecg")
                            metricCard("Bankroll", value: balance.formatted(), icon: "circle.grid.cross")
                            metricCard("ROI", value: signedPercent(roi), icon: "chart.line.uptrend.xyaxis")
                        }

                        Divider()
                            .overlay(AppTheme.border)
                            .padding(.horizontal, -16)

                        HStack {
                            Text("Active Bets")
                                .font(.title3.bold())
                            Spacer()
                            Text("Swipe to settle →")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(.top, 8)

                        if activeBets.isEmpty {
                            EmptySimulatorState {
                                showAddBet = true
                            }
                        } else {
                            VStack(spacing: 8) {
                                ForEach(activeBets) { bet in
                                    SwipeableBetCard(
                                        bet: bet,
                                        onWin: { settle(bet, as: .won) },
                                        onLoss: { settle(bet, as: .lost) }
                                    )
                                }
                            }

                            PotentialOutcomeCard(bets: activeBets)
                        }

                        if !settledBets.isEmpty {
                            Text("Bet History")
                                .font(.title3.bold())
                                .padding(.top, 10)

                            VStack(spacing: 8) {
                                ForEach(settledBets) { bet in
                                    SimulatorBetCard(bet: bet, showsStatus: true)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 96)
                }

                Button {
                    showAddBet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.accent, Color(red: 0.24, green: 0.02, blue: 0.04)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
                }
                .accessibilityLabel("Add new bet")
                .padding(.trailing, 18)
                .padding(.bottom, 20)
            }
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showAddBet) {
                AddBetView(balance: balance)
                    .presentationDetents([.height(660), .large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(24)
            }
        }
    }

    private func metricCard(_ title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.title3)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func signedPercent(_ value: Double) -> String {
        let number = abs(value).formatted(.number.precision(.fractionLength(1)))
        return "\(value >= 0 ? "+" : "-")\(number)%"
    }

    private func settle(_ bet: VirtualBet, as status: BetStatus) {
        guard bet.status == .pending else { return }
        bet.status = status
        bet.settledAt = .now

        if status == .won {
            modelContext.insert(
                BankrollEntry(
                    amount: bet.potentialReturn,
                    kind: .winReturn,
                    note: "Won: \(bet.eventName)"
                )
            )
        }

        guard notificationsEnabled else { return }
        let message = status == .won
            ? "Your bet on \(bet.eventName) was marked as won. +\(bet.potentialReturn.formatted()) B-Coins returned."
            : "Your bet on \(bet.eventName) was marked as lost."
        modelContext.insert(AppNotice(title: "Bet Settled", message: message, kind: .bet))
    }
}

private struct SwipeableBetCard: View {
    let bet: VirtualBet
    let onWin: () -> Void
    let onLoss: () -> Void

    @State private var dragOffset: CGFloat = 0
    private let settleThreshold: CGFloat = 105

    var body: some View {
        ZStack {
            HStack {
                Label("Won", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.white)
                    .padding(.leading, 22)
                Spacer()
                Label("Lost", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.white)
                    .padding(.trailing, 22)
            }
            .font(.headline)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [AppTheme.success, AppTheme.surface, AppTheme.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            SimulatorBetCard(bet: bet, showsStatus: false)
                .offset(x: dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            dragOffset = max(-140, min(140, value.translation.width))
                        }
                        .onEnded { value in
                            if value.translation.width >= settleThreshold {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    dragOffset = 180
                                }
                                onWin()
                            } else if value.translation.width <= -settleThreshold {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    dragOffset = -180
                                }
                                onLoss()
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                }
                            }
                        }
                )
        }
        .frame(minHeight: 148)
        .accessibilityAction(named: "Mark as won", onWin)
        .accessibilityAction(named: "Mark as lost", onLoss)
    }
}

private struct SimulatorBetCard: View {
    let bet: VirtualBet
    let showsStatus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Text(bet.sport)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                if showsStatus {
                    statusLabel
                }
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Odds")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(bet.odds.formatted(.number.precision(.fractionLength(2))))
                        .font(.title3)
                }
            }

            Text(bet.eventName)
                .font(.headline)
                .lineLimit(2)

            HStack(spacing: 12) {
                value("Stake", "\(bet.stake.formatted()) BC")
                value("Return", "\(bet.potentialReturn.formatted()) BC")
                value("Profit", "+\(bet.potentialProfit.formatted()) BC")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.border)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch bet.status {
        case .pending:
            EmptyView()
        case .won:
            Label("Won", systemImage: "checkmark")
                .foregroundStyle(AppTheme.success)
                .font(.caption)
        case .lost:
            Label("Lost", systemImage: "xmark")
                .foregroundStyle(AppTheme.accent)
                .font(.caption)
        }
    }

    private func value(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(text)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PotentialOutcomeCard: View {
    let bets: [VirtualBet]

    private var totalStaked: Int {
        bets.reduce(0) { $0 + $1.stake }
    }

    private var totalReturn: Int {
        bets.reduce(0) { $0 + $1.potentialReturn }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("If All Bets Win")
                .font(.headline)
            outcomeRow("Total Staked", value: "\(totalStaked.formatted()) B-Coins")
            outcomeRow("Total Return", value: "\(totalReturn.formatted()) B-Coins")
            Divider()
                .overlay(AppTheme.border)
            outcomeRow("Total Profit", value: "+\((totalReturn - totalStaked).formatted()) B-Coins", emphasized: true)
        }
        .padding(20)
        .background(AppTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
    }

    private func outcomeRow(_ title: String, value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(emphasized ? .white : AppTheme.secondaryText)
            Spacer()
            Text(value)
                .font(emphasized ? .headline : .body)
        }
    }
}

private struct EmptySimulatorState: View {
    let addAction: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "ticket")
                .font(.system(size: 34))
                .foregroundStyle(AppTheme.accent)
            Text("No Active Bets")
                .font(.headline)
            Text("Add a virtual bet to begin testing your strategy.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            Button("Add Your First Bet", action: addAction)
                .foregroundStyle(AppTheme.accent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AddBetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let balance: Int

    @State private var eventName = ""
    @State private var sport = "Football"
    @State private var oddsText = ""
    @State private var stakeText = ""
    @State private var attemptedSubmit = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case event
        case odds
        case stake
    }

    private var odds: Double? {
        Double(oddsText.replacingOccurrences(of: ",", with: "."))
    }

    private var stake: Int? {
        Int(stakeText)
    }

    private var potentialReturn: Int? {
        guard let odds, let stake else { return nil }
        return Int((Double(stake) * odds).rounded())
    }

    private var validationMessage: String? {
        if eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter an event name."
        }
        guard let odds, odds >= 1.01, odds <= 1_000 else {
            return "Enter decimal odds between 1.01 and 1,000."
        }
        guard let stake, stake > 0 else {
            return "Enter a positive whole-number stake."
        }
        guard stake <= balance else {
            return "Your stake cannot exceed the available bankroll."
        }
        return nil
    }

    private var canSubmit: Bool {
        validationMessage == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Add New Bet")
                            .font(.title3.bold())
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: 44, height: 44)
                        }
                        .foregroundStyle(.white)
                        .accessibilityLabel("Close")
                    }

                    inputField(
                        title: "Event Name",
                        placeholder: "e.g., Lakers vs Warriors",
                        text: $eventName,
                        keyboard: .default,
                        field: .event
                    )

                    VStack(alignment: .leading, spacing: 9) {
                        Text("Sport")
                            .font(.subheadline)
                        Menu {
                            ForEach(AppData.sports, id: \.self) { value in
                                Button(value) {
                                    sport = value
                                }
                            }
                        } label: {
                            HStack {
                                Text(sport)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(AppTheme.raised)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .foregroundStyle(.white)
                    }

                    inputField(
                        title: "Odds (Decimal)",
                        placeholder: "e.g., 2.10",
                        text: $oddsText,
                        keyboard: .decimalPad,
                        field: .odds
                    )

                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text("Stake (B-Coins)")
                                .font(.subheadline)
                            Spacer()
                            Button("Use recommended") {
                                stakeText = String(recommendedStake)
                            }
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                        }

                        TextField("e.g., 200", text: $stakeText)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .stake)
                            .padding(.horizontal, 16)
                            .frame(height: 48)
                            .background(AppTheme.raised)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Label(
                            "Recommended: 1–3% of bankroll (\(recommendedRange))",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    }

                    if let stake, let potentialReturn, odds != nil {
                        HStack {
                            estimate("Potential Return", value: "\(potentialReturn.formatted()) BC")
                            estimate("Net Profit", value: "\((potentialReturn - stake).formatted()) BC")
                        }
                    }

                    if attemptedSubmit, let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(AppTheme.accent)
                    }

                    Button {
                        submit()
                    } label: {
                        Text("Add Bet")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .foregroundStyle(canSubmit ? .white : AppTheme.secondaryText)
                            .background(canSubmit ? AppTheme.accent : AppTheme.accent.opacity(0.52))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!canSubmit)
                    .padding(.top, 2)
                }
                .padding(24)
            }
            .background(AppTheme.surface.ignoresSafeArea())
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func inputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.subheadline)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .focused($focusedField, equals: field)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(AppTheme.raised)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func estimate(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var recommendedStake: Int {
        max(1, Int((Double(balance) * 0.02).rounded()))
    }

    private var recommendedRange: String {
        let low = max(1, Int(Double(balance) * 0.01))
        let high = max(1, Int(Double(balance) * 0.03))
        return "\(low.formatted())–\(high.formatted()) B-Coins"
    }

    private func submit() {
        attemptedSubmit = true
        guard canSubmit, let odds, let stake else { return }

        let trimmedName = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(
            VirtualBet(eventName: trimmedName, sport: sport, odds: odds, stake: stake)
        )
        modelContext.insert(
            BankrollEntry(amount: -stake, kind: .stake, note: "Stake: \(trimmedName)")
        )
        dismiss()
    }
}
