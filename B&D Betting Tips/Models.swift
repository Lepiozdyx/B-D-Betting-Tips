import Foundation
import SwiftData

enum BetStatus: String, Codable, CaseIterable {
    case pending
    case won
    case lost
}

@Model
final class VirtualBet {
    var id: UUID
    var eventName: String
    var sport: String
    var odds: Double
    var stake: Int
    var statusRawValue: String
    var createdAt: Date
    var settledAt: Date?

    init(
        eventName: String,
        sport: String,
        odds: Double,
        stake: Int,
        status: BetStatus = .pending,
        createdAt: Date = .now
    ) {
        self.id = UUID()
        self.eventName = eventName
        self.sport = sport
        self.odds = odds
        self.stake = stake
        self.statusRawValue = status.rawValue
        self.createdAt = createdAt
    }

    var status: BetStatus {
        get { BetStatus(rawValue: statusRawValue) ?? .pending }
        set { statusRawValue = newValue.rawValue }
    }

    var potentialReturn: Int {
        Int((Double(stake) * odds).rounded())
    }

    var potentialProfit: Int {
        potentialReturn - stake
    }
}

enum BankrollEntryKind: String, Codable {
    case stake
    case winReturn
    case quizReward
    case reset
}

@Model
final class BankrollEntry {
    var id: UUID
    var amount: Int
    var kindRawValue: String
    var note: String
    var createdAt: Date

    init(amount: Int, kind: BankrollEntryKind, note: String, createdAt: Date = .now) {
        self.id = UUID()
        self.amount = amount
        self.kindRawValue = kind.rawValue
        self.note = note
        self.createdAt = createdAt
    }
}

@Model
final class QuizAttempt {
    var id: UUID
    var completedAt: Date
    var correctAnswers: Int
    var reward: Int

    init(correctAnswers: Int, reward: Int, completedAt: Date = .now) {
        self.id = UUID()
        self.completedAt = completedAt
        self.correctAnswers = correctAnswers
        self.reward = reward
    }
}

enum NoticeKind: String, Codable {
    case quiz
    case tip
    case bet

    var icon: String {
        switch self {
        case .quiz: "brain.head.profile"
        case .tip: "book"
        case .bet: "waveform.path.ecg"
        }
    }
}

@Model
final class AppNotice {
    var id: UUID
    var title: String
    var message: String
    var kindRawValue: String
    var createdAt: Date
    var isRead: Bool

    init(
        title: String,
        message: String,
        kind: NoticeKind,
        createdAt: Date = .now,
        isRead: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.message = message
        self.kindRawValue = kind.rawValue
        self.createdAt = createdAt
        self.isRead = isRead
    }

    var kind: NoticeKind {
        NoticeKind(rawValue: kindRawValue) ?? .tip
    }
}

struct BettingTip: Identifiable, Hashable {
    let id: Int
    let category: TipCategory
    let title: String
    let detail: String
    let content: String
    let keyTakeaway: String
    let relatedTipIDs: [Int]

    init(
        id: Int,
        category: TipCategory,
        title: String,
        detail: String,
        content: String = "",
        keyTakeaway: String = "",
        relatedTipIDs: [Int] = []
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.detail = detail
        self.content = content
        self.keyTakeaway = keyTakeaway
        self.relatedTipIDs = relatedTipIDs
    }
}

enum TipCategory: String, CaseIterable, Identifiable {
    case mathematics = "Mathematics"
    case strategy = "Strategy"
    case psychology = "Psychology"
    case analysis = "Analysis"

    var id: String { rawValue }
}

struct QuizQuestion: Identifiable, Hashable {
    let id: Int
    let prompt: String
    let answers: [String]
    let correctIndex: Int
    let explanation: String
}
