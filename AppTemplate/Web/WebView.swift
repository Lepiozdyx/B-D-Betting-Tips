import SwiftUI

struct WebView: View {
    let url: URL
    let onAccept: () -> Void

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            WebViewManager(url: url, onAccept: onAccept)
        }
    }
}
