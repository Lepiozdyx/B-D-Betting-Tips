import SwiftUI

struct OfflinePolicyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Internet Connection")
                .font(.title2.bold())

            Text("To accept the Privacy Policy and use the app, you need an internet connection. After you accept the agreement, you will be able to use the app offline.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
