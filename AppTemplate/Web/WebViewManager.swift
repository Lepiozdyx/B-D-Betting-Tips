import SwiftUI
import WebKit
import Foundation
import UIKit

fileprivate final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

struct WebViewManager: UIViewRepresentable {
    let url: URL
    let onAccept: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAccept: onAccept)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        let scriptSource = """
        (function() {
            if (!window.CreateYourselfPolicy) {
                window.CreateYourselfPolicy = {};
            }
            function notifyPolicy(value) {
                window.webkit.messageHandlers.policy.postMessage(value);
            }
            window.CreateYourselfPolicy.recieve = notifyPolicy;
            window.CreateYourselfPolicy.receive = notifyPolicy;
        })();
        """
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(script)

        let handler = WeakScriptMessageHandler(delegate: context.coordinator)
        context.coordinator.messageHandler = handler
        configuration.userContentController.add(handler, name: "policy")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = WebManager.safariUserAgent()
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

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "policy")
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        fileprivate var messageHandler: WeakScriptMessageHandler?
        let onAccept: () -> Void

        init(onAccept: @escaping () -> Void) {
            self.onAccept = onAccept
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "policy",
                  let value = message.body as? String,
                  value == "accept" else { return }

            DispatchQueue.main.async {
                self.onAccept()
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {}

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

        func webView(
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

        func webView(
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

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

            alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
                completionHandler()
            }))

            topViewController()?.present(alertController, animated: true, completion: nil)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

            alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
                completionHandler(true)
            }))

            alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
                completionHandler(false)
            }))

            topViewController()?.present(alertController, animated: true, completion: nil)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .actionSheet)

            alertController.addTextField { textField in
                textField.text = defaultText
            }

            alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: { _ in
                if let text = alertController.textFields?.first?.text {
                    completionHandler(text)
                } else {
                    completionHandler(defaultText)
                }
            }))

            alertController.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
                completionHandler(nil)
            }))

            topViewController()?.present(alertController, animated: true, completion: nil)
        }
    }
}
