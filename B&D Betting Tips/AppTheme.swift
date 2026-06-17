import SwiftUI
import UIKit

enum AppTheme {
    static let background = Color(red: 0.09, green: 0.10, blue: 0.12)
    static let surface = Color(red: 0.06, green: 0.07, blue: 0.08)
    static let raised = Color(red: 0.12, green: 0.14, blue: 0.17)
    static let border = Color.white.opacity(0.08)
    static let secondaryText = Color(red: 0.66, green: 0.68, blue: 0.72)
    static let accent = Color(red: 0.92, green: 0.06, blue: 0.10)
    static let success = Color(red: 0.20, green: 0.75, blue: 0.38)
}

struct AppCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.border)
            }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .foregroundStyle(.white)
            .background(AppTheme.accent.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

enum AssetScaleMode {
    case cover
    case contain
    case fill
}

struct AssetArtwork: View {
    let name: String
    var mode: AssetScaleMode = .contain

    var body: some View {
        GeometryReader { proxy in
            artwork
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .accessibilityLabel("Artwork: \(name)")
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = UIImage(named: name) {
            switch mode {
            case .cover:
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            case .contain:
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            case .fill:
                Image(uiImage: image)
                    .resizable()
            }
        } else {
            ZStack {
                LinearGradient(
                    colors: [AppTheme.surface, AppTheme.accent.opacity(0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.title2)
                    Text(name)
                        .font(.caption2.monospaced())
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.6)
                }
                .foregroundStyle(AppTheme.secondaryText)
                .padding(12)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.55))
            }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        AppCard {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 34))
                    .foregroundStyle(AppTheme.accent)
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

extension View {
    func appScreen() -> some View {
        self
            .background(AppTheme.background.ignoresSafeArea())
            .foregroundStyle(.white)
    }
}
