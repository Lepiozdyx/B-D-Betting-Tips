import SwiftUI

struct WebView: View {
    let url: URL
    let onAccept: () -> Void

    var body: some View {
        WebViewManager(url: url, onAccept: onAccept)
            .ignoresSafeArea()
    }
}
