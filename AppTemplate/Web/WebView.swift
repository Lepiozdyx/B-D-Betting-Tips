import SwiftUI

struct WebView: View {
    let url: URL
    var wvm: WebViewManager?
    
    init(url: URL){
        self.url = url
    }
    
    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            WebViewManager(url: url)
        }
    }
}
