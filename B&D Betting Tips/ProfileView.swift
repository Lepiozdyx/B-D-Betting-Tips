import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \QuizAttempt.completedAt, order: .reverse) private var quizAttempts: [QuizAttempt]
    @Query(sort: \BankrollEntry.createdAt) private var bankrollEntries: [BankrollEntry]

    @AppStorage("profileDisplayName") private var displayName = "Sports Analyst"
    @AppStorage("profileUsername") private var username = "analyst_pro"
    @AppStorage("profileFavoriteSport") private var favoriteSport = "Football"
    @AppStorage("profileExperience") private var experience = "Intermediate"
    @AppStorage("profileMemberSince") private var memberSince = Self.defaultMemberSince
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("readTipIDs") private var readTipIDs = ""
    @AppStorage("favoriteTipIDs") private var favoriteTipIDs = ""

    @State private var showEditor = false
    @State private var showResetConfirmation = false
    @State private var resetErrorMessage: String?

    private static let defaultMemberSince =
        Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 1))?.timeIntervalSince1970
        ?? Date.now.timeIntervalSince1970

    private var completedTipCount: Int {
        Set(readTipIDs.split(separator: ",").compactMap { Int($0) }).count
    }

    private var quizAccuracy: Int? {
        let totalAnswers = quizAttempts.count * AppData.quizQuestions.count
        guard totalAnswers > 0 else { return nil }
        let correctAnswers = quizAttempts.reduce(0) { $0 + $1.correctAnswers }
        return Int((Double(correctAnswers) / Double(totalAnswers) * 100).rounded())
    }

    private var earnedBCoins: Int {
        bankrollEntries
            .filter { $0.kindRawValue == BankrollEntryKind.quizReward.rawValue }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                        .padding(.horizontal, 24)
                        .padding(.top, 28)
                        .padding(.bottom, 24)

                    profileFacts
                        .padding(.horizontal, 24)
                        .padding(.bottom, 26)

                    ZStack(alignment: .top) {
                        profileBackdrop

                        VStack(alignment: .leading, spacing: 26) {
                            learningProgress
                            settings
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 18)
                        .padding(.bottom, 40)
                    }
                }
            }
            .appScreen()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Close profile")
                }
            }
            .sheet(isPresented: $showEditor) {
                EditProfileView()
            }
            .confirmationDialog(
                "Reset all simulator data?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset Data", role: .destructive) {
                    resetData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All bets, quiz attempts, notifications, and learning progress will be permanently removed.")
            }
            .alert(
                "Reset Failed",
                isPresented: Binding(
                    get: { resetErrorMessage != nil },
                    set: { if !$0 { resetErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(resetErrorMessage ?? "The simulator data could not be reset.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var profileHeader: some View {
        HStack(spacing: 16) {
            ProfileAvatar(displayName: displayName, size: 80)

            VStack(alignment: .leading, spacing: 5) {
                Text(nonEmpty(displayName, fallback: "Sports Analyst"))
                    .font(.title2.bold())
                    .lineLimit(2)
                Text(formattedUsername)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                Text("Member since \(memberSinceText)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showEditor = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.headline)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.accent, in: Circle())
            }
            .foregroundStyle(.white)
            .accessibilityLabel("Edit profile")
        }
        .padding(.bottom, 20)
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(AppTheme.border)
        }
    }

    private var profileFacts: some View {
        HStack(spacing: 12) {
            profileFact(title: "Favorite Sport", value: nonEmpty(favoriteSport, fallback: "Not set"))
            profileFact(title: "Experience", value: nonEmpty(experience, fallback: "Not set"))
        }
    }

    private func profileFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.subheadline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(AppTheme.raised)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var profileBackdrop: some View {
        ZStack {
            AppTheme.background
            LinearGradient(
                colors: [
                    AppTheme.accent.opacity(0.12),
                    Color.clear,
                    AppTheme.accent.opacity(0.2)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            Canvas { context, size in
                for row in 0..<5 {
                    for column in 0..<7 where (row + column).isMultiple(of: 2) {
                        let rect = CGRect(
                            x: CGFloat(column) * 8 + 8,
                            y: CGFloat(row) * 8 + size.height * 0.45,
                            width: 2,
                            height: 2
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(AppTheme.accent.opacity(0.5)))
                    }
                }
            }
        }
    }

    private var learningProgress: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Learning Progress")
                .font(.title3)

            AppCard {
                VStack(spacing: 18) {
                    progressRow(
                        icon: "book",
                        title: "Tips Completed",
                        value: "\(min(completedTipCount, AppData.tips.count)) / \(AppData.tips.count)",
                        tint: AppTheme.accent
                    )
                    progressRow(
                        icon: "brain.head.profile",
                        title: "Quiz Accuracy",
                        value: quizAccuracy.map { "\($0)%" } ?? "No attempts",
                        tint: .white
                    )
                    progressRow(
                        icon: "circle.grid.cross",
                        title: "Total B-Coins Earned",
                        value: earnedBCoins > 0 ? earnedBCoins.formatted() : "0",
                        tint: .white
                    )
                }
            }
        }
    }

    private func progressRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(value == "No attempts" ? AppTheme.secondaryText : .white)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.title3)

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: "bell")
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notifications")
                        Text("Receive tips and updates")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                        .tint(AppTheme.accent)
                }
                .padding(18)

                Divider()
                    .overlay(AppTheme.border)

                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reset Simulator Data")
                            Text("Clear all bets and reset balance")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    .padding(18)
                    .contentShape(Rectangle())
                }
            }
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var formattedUsername: String {
        let cleanUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        return cleanUsername.isEmpty ? "@not_set" : "@\(cleanUsername)"
    }

    private var memberSinceText: String {
        Date(timeIntervalSince1970: memberSince)
            .formatted(.dateTime.month(.wide).year())
    }

    private func nonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func resetData() {
        do {
            try modelContext.delete(model: VirtualBet.self)
            try modelContext.delete(model: BankrollEntry.self)
            try modelContext.delete(model: QuizAttempt.self)
            try modelContext.delete(model: AppNotice.self)
            readTipIDs = ""
            favoriteTipIDs = ""
            try modelContext.save()
        } catch {
            resetErrorMessage = error.localizedDescription
        }
    }
}

private struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("profileDisplayName") private var storedName = "Sports Analyst"
    @AppStorage("profileUsername") private var storedUsername = "analyst_pro"
    @AppStorage("profileFavoriteSport") private var storedSport = "Football"
    @AppStorage("profileExperience") private var storedExperience = "Intermediate"

    @State private var name = ""
    @State private var username = ""
    @State private var sport = ""
    @State private var experience = ""
    @State private var showAvatarInfo = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name
        case username
    }

    private let experienceLevels = ["Beginner", "Intermediate", "Advanced"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    editorHeader

                    Divider()
                        .overlay(AppTheme.border)

                    editorPicker(title: "Favorite Sport", selection: $sport, values: AppData.sports)
                    editorPicker(title: "Experience Level", selection: $experience, values: experienceLevels)

                    Button {
                        dismiss()
                    } label: {
                        Label("Cancel", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppTheme.raised)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .foregroundStyle(.white)
                    .padding(.top, 2)
                }
                .padding(24)
            }
            .appScreen()
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 8)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                name = storedName
                username = storedUsername
                sport = validValue(storedSport, in: AppData.sports)
                experience = validValue(storedExperience, in: experienceLevels)
            }
            .alert("Avatar Placeholder", isPresented: $showAvatarInfo) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The gradient avatar uses your initials. Photo upload is not part of the local profile.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var editorHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                ProfileAvatar(displayName: name, size: 80)

                Button {
                    showAvatarInfo = true
                } label: {
                    Image(systemName: "camera")
                        .font(.caption.bold())
                        .frame(width: 32, height: 32)
                        .background(AppTheme.accent, in: Circle())
                }
                .foregroundStyle(.white)
                .accessibilityLabel("Avatar options")
            }

            VStack(spacing: 10) {
                profileTextField("Display name", text: $name, field: .name)
                profileTextField("Username", text: $username, field: .username)
            }

            Button {
                save()
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.headline)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.accent, in: Circle())
            }
            .foregroundStyle(.white)
            .accessibilityLabel("Save profile")
        }
    }

    private func profileTextField(_ title: String, text: Binding<String>, field: Field) -> some View {
        TextField(title, text: text)
            .focused($focusedField, equals: field)
            .textInputAutocapitalization(field == .username ? .never : .words)
            .autocorrectionDisabled(field == .username)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(AppTheme.raised)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func editorPicker(title: String, selection: Binding<String>, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)

            Menu {
                Button("Not set") {
                    selection.wrappedValue = ""
                }
                ForEach(values, id: \.self) { value in
                    Button(value) {
                        selection.wrappedValue = value
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.isEmpty ? "Not set" : selection.wrappedValue)
                        .foregroundStyle(selection.wrappedValue.isEmpty ? AppTheme.secondaryText : .white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(.horizontal, 16)
                .frame(height: 44)
                .background(AppTheme.raised)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func save() {
        storedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        storedUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        storedSport = sport
        storedExperience = experience
        dismiss()
    }

    private func validValue(_ value: String, in values: [String]) -> String {
        values.contains(value) ? value : ""
    }
}

private struct ProfileAvatar: View {
    let displayName: String
    let size: CGFloat

    private var initials: String {
        let value = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let letters = value
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
        return letters.isEmpty ? "BD" : letters
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.3, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.accent.opacity(0.95),
                                Color(red: 0.22, green: 0.03, blue: 0.05),
                                Color(red: 0.04, green: 0.05, blue: 0.07)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.05))
            }
            .accessibilityLabel("Profile avatar, initials \(initials)")
    }
}
