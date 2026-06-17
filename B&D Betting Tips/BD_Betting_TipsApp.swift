import SwiftData
import SwiftUI

struct BDBettingTipsApp: View {
    private let modelContainer: ModelContainer?
    private let storeErrorMessage: String?

    init() {
        let schema = Schema([
            VirtualBet.self,
            BankrollEntry.self,
            QuizAttempt.self,
            AppNotice.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            storeErrorMessage = nil
        } catch {
            modelContainer = nil
            storeErrorMessage = error.localizedDescription
        }
    }

    var body: some View {
        if let modelContainer {
            RootView()
                .preferredColorScheme(.dark)
                .modelContainer(modelContainer)
        } else {
            ContentUnavailableView {
                Label("Data Store Unavailable", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text(storeErrorMessage ?? "The local data store could not be opened.")
            } actions: {
                Text("Restart the app. If the problem continues, reinstall it to recreate local data.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .preferredColorScheme(.dark)
        }
    }
}
