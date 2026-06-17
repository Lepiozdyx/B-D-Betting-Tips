import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasAcceptedAgeNotice") private var hasAcceptedAgeNotice = false

    var body: some View {
        Group {
            if !hasCompletedOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            } else if !hasAcceptedAgeNotice {
                AgeConfirmationView {
                    hasAcceptedAgeNotice = true
                }
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.25), value: hasAcceptedAgeNotice)
    }
}

private struct OnboardingPage {
    let icon: String
    let title: String
    let message: String
}

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages = [
        OnboardingPage(
            icon: "book",
            title: "Learn Sports Betting Basics",
            message: "Master bankroll management, betting strategies, and sports analytics through 20 practical tips."
        ),
        OnboardingPage(
            icon: "circle.grid.cross",
            title: "Practice With Virtual B-Coins",
            message: "Test strategies without real money. Track virtual bets, experiment, and build confidence."
        ),
        OnboardingPage(
            icon: "chart.line.uptrend.xyaxis",
            title: "Track Results & Improve",
            message: "Review your performance and learn from every virtual decision."
        )
    ]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            AssetArtwork(name: "sports_stadium_background", mode: .cover)
                .ignoresSafeArea()
                .opacity(0.5)
            LinearGradient(
                colors: [.black.opacity(0.2), .black.opacity(0.68)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button("Skip", action: onFinish)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding()
                }

                TabView(selection: $page) {
                    ForEach(pages.indices, id: \.self) { index in
                        VStack(spacing: 28) {
                            Spacer()
                            Image(systemName: pages[index].icon)
                                .font(.system(size: 58, weight: .medium))
                                .frame(width: 128, height: 128)
                                .background(
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.black.opacity(0.8), AppTheme.accent.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )

                            Text(pages[index].title)
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)
                            Text(pages[index].message)
                                .font(.title3)
                                .foregroundStyle(AppTheme.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineSpacing(6)
                            Spacer()
                        }
                        .padding(.horizontal, 30)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                HStack(spacing: 16) {
                    if page > 0 {
                        Button {
                            page -= 1
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(AppTheme.raised)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                        .foregroundStyle(.white)
                    }

                    Button {
                        if page == pages.count - 1 {
                            onFinish()
                        } else {
                            page += 1
                        }
                    } label: {
                        HStack {
                            Text(page == pages.count - 1 ? "Finish" : "Next")
                            if page < pages.count - 1 {
                                Image(systemName: "arrow.right")
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
            }
        }
        .foregroundStyle(.white)
    }
}

struct AgeConfirmationView: View {
    let onAccept: () -> Void
    @State private var showExitMessage = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AppCard {
                VStack(spacing: 24) {
                    Image(systemName: "shield")
                        .font(.system(size: 42))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 80, height: 80)
                        .background(AppTheme.accent.opacity(0.18), in: Circle())

                    Text("18+ Educational Simulator")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("B&D Betting Tips is a virtual educational simulator.\n\nNo real-money betting, payments, deposits, or withdrawals are available.\n\nPlay responsibly.")
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)

                    Label(
                        "By continuing, you confirm that you are 18 or older and understand this is for educational purposes only.",
                        systemImage: "exclamationmark.circle"
                    )
                    .font(.subheadline)
                    .padding()
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button("I Understand", action: onAccept)
                        .buttonStyle(PrimaryButtonStyle())

                    Button("Exit") {
                        showExitMessage = true
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(AppTheme.raised)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                }
            }
            .padding(20)
        }
        .foregroundStyle(.white)
        .alert("Age Confirmation Required", isPresented: $showExitMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Close the app to exit. Access remains locked until the age notice is accepted.")
        }
    }
}
