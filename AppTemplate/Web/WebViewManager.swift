import SwiftUI
import WebKit
import Foundation
import UIKit
import UniformTypeIdentifiers

struct WebViewManager: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.bounces = true
        webView.scrollView.contentInsetAdjustmentBehavior = .always
        webView.scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)

        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard uiView.url == nil else { return }
        uiView.load(URLRequest(url: url))
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        weak var webView: WKWebView?

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {}
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let finalURL = webView.url else {
                return
            }
            
            if finalURL.absoluteString != WebManager.initialURL && !finalURL.absoluteString.contains("google"){
                if WebManager.getSavedUrl() == ""
                {
                    WebManager.trySetSavedUrl(finalURL)
                }
            } else {
                print("Failed to load: \(finalURL)")
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Navigation failed")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Navigation failed")
        }
        
        func topViewController(from root: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
            guard let root = root else { return nil }
            
            var top = root
            while let presented = top.presentedViewController {
                top = presented
            }
            
            if let nav = top as? UINavigationController {
                return topViewController(from: nav.visibleViewController)
            }
            
            if let tab = top as? UITabBarController {
                return topViewController(from: tab.selectedViewController)
            }
            
            return top
        }
        
        public func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let url = navigationAction.request.url else {
                return nil
            }
            webView.load(URLRequest(url: url))
            return nil
        }
        
        public func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            DispatchQueue.main.async {
                if let url = navigationAction.request.url,
                   let scheme = url.scheme?.lowercased() {
                    let inAppSchemes: Set<String> = ["http", "https", "about", "data", "file"]
                    if !inAppSchemes.contains(scheme) {
                        print("Opening url: \(url)")
                        UIApplication.shared.open(url, options: [:]) { success in
                            if success {
                                print("Successfully opened url: \(url)")
                            } else {
                                print("Failed to open url: \(url)")
                            }
                        }
                        decisionHandler(.cancel)
                        return
                    }
                }
                decisionHandler(.allow)
            }
        }
        
        public func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action) in
                completionHandler()
            }))
            
            topViewController()?.present(alertController, animated: true, completion: nil)
        }
        
        public func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            
            alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action) in
                completionHandler(true)
            }))
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (action) in
                completionHandler(false)
            }))
            
            topViewController()?.present(alertController, animated: true, completion: nil)
        }
        
        public func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .actionSheet)
            
            alertController.addTextField { (textField) in
                textField.text = defaultText
            }
            
            alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { (action) in
                if let text = alertController.textFields?.first?.text {
                    completionHandler(text)
                } else {
                    completionHandler(defaultText)
                }
                
            }))
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (action) in
                
                completionHandler(nil)
                
            }))
            
            topViewController()?.present(alertController, animated: true, completion: nil)
        }
    }
}
