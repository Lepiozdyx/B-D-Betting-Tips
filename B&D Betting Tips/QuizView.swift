import SwiftData
import SwiftUI

struct QuizHomeView: View {
    @Binding var selection: AppTab
    @Query(sort: \QuizAttempt.completedAt, order: .reverse) private var attempts: [QuizAttempt]
    @State private var showQuiz = false

    private var canEarnRewardToday: Bool {
        !attempts.contains { Calendar.current.isDateInToday($0.completedAt) && $0.reward > 0 }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 42))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 80, height: 80)
                    .background(AppTheme.accent.opacity(0.22), in: Circle())

                Text("Quiz")
                    .font(.title2.bold())
                    .padding(.top, 26)

                VStack(spacing: 7) {
                    Text(
                        canEarnRewardToday
                            ? "Each quiz gives you a chance to earn B-Coins!"
                            : "Today's reward is complete. Retakes are for practice."
                    )
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity, minHeight: 98)
                .background(AppTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.top, 54)

                Button {
                    showQuiz = true
                } label: {
                    Text("Start Quiz!")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .frame(height: 57)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer(minLength: 90)
            }
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showQuiz) {
                QuizSessionView(
                    isRewardEligible: canEarnRewardToday,
                    onDashboard: {
                        showQuiz = false
                        selection = .dashboard
                    }
                )
            }
        }
    }
}

private struct QuizSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BankrollEntry.createdAt) private var bankrollEntries: [BankrollEntry]

    let isRewardEligible: Bool
    let onDashboard: () -> Void

    @State private var questionIndex = 0
    @State private var correctAnswers = 0
    @State private var secondsRemaining = 20
    @State private var selectedAnswer: Int?
    @State private var showResult = false
    @State private var timerTask: Task<Void, Never>?
    @State private var hasClaimedReward: Bool
    @State private var awardedReward = 0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    init(isRewardEligible: Bool, onDashboard: @escaping () -> Void) {
        self.isRewardEligible = isRewardEligible
        self.onDashboard = onDashboard
        _hasClaimedReward = State(initialValue: !isRewardEligible)
    }

    private var question: QuizQuestion {
        AppData.quizQuestions[questionIndex]
    }

    private var currentBalance: Int {
        AppData.startingBalance + bankrollEntries.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        Group {
            if showResult {
                QuizResultView(
                    correctAnswers: correctAnswers,
                    reward: awardedReward,
                    updatedBalance: currentBalance,
                    onRetake: resetQuiz,
                    onDashboard: onDashboard
                )
            } else {
                questionView
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .appScreen()
        .onAppear {
            if !showResult {
                startTimer()
            }
        }
        .onDisappear {
            timerTask?.cancel()
        }
    }

    private var questionView: some View {
        ScrollView {
            VStack(spacing: 0) {
                quizHeader

                Text("\(secondsRemaining)")
                    .font(.system(size: 36, weight: .regular, design: .rounded))
                    .frame(width: 96, height: 96)
                    .overlay {
                        Circle()
                            .stroke(AppTheme.raised, lineWidth: 4)
                    }
                    .padding(.top, 40)
                    .accessibilityLabel("\(secondsRemaining) seconds remaining")

                Text(question.prompt)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 22)
                    .frame(maxWidth: .infinity, minHeight: 124)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.top, 17)

                VStack(spacing: 11) {
                    ForEach(question.answers.indices, id: \.self) { index in
                        answerButton(index)
                    }
                }
                .padding(.top, 24)

                if selectedAnswer != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Explanation")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                        Text(question.explanation)
                            .font(.subheadline)
                            .lineSpacing(4)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.raised)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.top, 14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 26)
            .padding(.bottom, 28)
        }
    }

    private var quizHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Sports Knowledge Quiz")
                    .font(.title3.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Label("+50 per correct", systemImage: "circle.grid.cross")
                    .font(.subheadline)
                    .lineLimit(1)
            }

            HStack {
                Text("Question \(questionIndex + 1) / \(AppData.quizQuestions.count)")
                Spacer()
                Text("\(progressPercent)%")
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.secondaryText)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.raised)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, AppTheme.accent.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * progress))
                }
            }
            .frame(height: 8)
        }
    }

    private func answerButton(_ index: Int) -> some View {
        Button {
            submit(index)
        } label: {
            HStack(spacing: 14) {
                Text(question.answers[index])
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                Spacer()
                answerIcon(index)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
            .background(answerBackground(index))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if selectedAnswer != nil, index == question.correctIndex {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.success.opacity(0.75), lineWidth: 1)
                }
            }
        }
        .foregroundStyle(.white)
        .disabled(selectedAnswer != nil)
    }

    @ViewBuilder
    private func answerIcon(_ index: Int) -> some View {
        if let selectedAnswer {
            if index == question.correctIndex {
                Image(systemName: "checkmark.square.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.success)
            } else if index == selectedAnswer {
                Image(systemName: "xmark")
                    .font(.title2.bold())
                    .foregroundStyle(Color(red: 0.62, green: 0.02, blue: 0.04))
            }
        }
    }

    private func answerBackground(_ index: Int) -> Color {
        guard let selectedAnswer else { return AppTheme.surface }
        if index == selectedAnswer, index != question.correctIndex {
            return AppTheme.accent
        }
        return AppTheme.surface
    }

    private var progress: CGFloat {
        CGFloat(questionIndex + 1) / CGFloat(AppData.quizQuestions.count)
    }

    private var progressPercent: Int {
        Int(progress * 100)
    }

    private func startTimer() {
        timerTask?.cancel()
        secondsRemaining = 20
        timerTask = Task {
            while !Task.isCancelled && secondsRemaining > 0 && selectedAnswer == nil {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                secondsRemaining -= 1
            }
            if !Task.isCancelled && secondsRemaining == 0 && selectedAnswer == nil {
                submit(nil)
            }
        }
    }

    private func submit(_ answer: Int?) {
        guard selectedAnswer == nil else { return }
        timerTask?.cancel()
        selectedAnswer = answer ?? -1

        if answer == question.correctIndex {
            correctAnswers += 1
        }

        Task {
            try? await Task.sleep(for: .milliseconds(1_350))
            advance()
        }
    }

    private func advance() {
        if questionIndex == AppData.quizQuestions.count - 1 {
            completeQuiz()
        } else {
            questionIndex += 1
            selectedAnswer = nil
            startTimer()
        }
    }

    private func completeQuiz() {
        timerTask?.cancel()
        let reward = hasClaimedReward ? 0 : correctAnswers * 50
        awardedReward = reward
        modelContext.insert(QuizAttempt(correctAnswers: correctAnswers, reward: reward))

        if reward > 0 {
            hasClaimedReward = true
            modelContext.insert(
                BankrollEntry(amount: reward, kind: .quizReward, note: "Daily quiz reward")
            )
            if notificationsEnabled {
                modelContext.insert(
                    AppNotice(
                        title: "Quiz Completed",
                        message: "You earned \(reward.formatted()) B-Coins from today's quiz.",
                        kind: .quiz
                    )
                )
            }
        }
        showResult = true
    }

    private func resetQuiz() {
        questionIndex = 0
        correctAnswers = 0
        awardedReward = 0
        selectedAnswer = nil
        showResult = false
        startTimer()
    }
}

private struct QuizResultView: View {
    let correctAnswers: Int
    let reward: Int
    let updatedBalance: Int
    let onRetake: () -> Void
    let onDashboard: () -> Void

    var body: some View {
        ZStack {
            AssetArtwork(name: "sports_stadium_background", mode: .cover)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.25),
                    AppTheme.accent.opacity(0.34),
                    AppTheme.accent.opacity(0.84)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: min(86, max(44, geometry.size.height * 0.08)))

                        VStack(spacing: 22) {
                            Image(systemName: "trophy")
                                .font(.system(size: 52))
                                .foregroundStyle(.white)
                                .frame(width: 128, height: 128)
                                .background(
                                    LinearGradient(
                                        colors: [Color.black.opacity(0.65), AppTheme.accent],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: Circle()
                                )

                            Text("Quiz Complete!")
                                .font(.largeTitle.bold())

                            VStack(spacing: 18) {
                                resultRow("Correct Answers", "\(correctAnswers) / \(AppData.quizQuestions.count)")
                                resultRow("Accuracy", "\(correctAnswers * 100 / AppData.quizQuestions.count)%")

                                Divider()
                                    .overlay(AppTheme.border)

                                resultRow("Coins Earned", "+\(reward)", showsCoin: true)

                                VStack(spacing: 5) {
                                    Text("Updated Balance")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.secondaryText)
                                    Text("\(updatedBalance.formatted()) B-Coins")
                                        .font(.title2)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity)
                                .background(AppTheme.raised)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .padding(24)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                            if reward == 0 {
                                Text("Today's reward was already claimed. This attempt was saved as practice.")
                                    .font(.caption)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }

                            HStack(spacing: 12) {
                                Button(action: onRetake) {
                                    Label("Retake\nQuiz", systemImage: "arrow.counterclockwise")
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 80)
                                        .background(AppTheme.raised)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }

                                Button(action: onDashboard) {
                                    Label("Dashboard", systemImage: "house")
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 80)
                                        .background(AppTheme.accent)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 78)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
    }

    private func resultRow(_ title: String, _ value: String, showsCoin: Bool = false) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
            if showsCoin {
                Image(systemName: "circle.grid.cross")
            }
            Text(value)
                .font(.title2)
        }
    }
}
