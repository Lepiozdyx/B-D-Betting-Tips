import Foundation
import UIKit

extension AppDelegate: UNUserNotificationCenterDelegate {

    func formulateRequest(initialUrl: String) -> String {
        initialUrl
    }

    func initApp() {
        routeLaunch()
    }

    func routeLaunch() {
        if WebManager.isPolicyAccepted {
            onGameStart()
            return
        }

        if !WebManager.isInternetAvailable() {
            showOfflineScreen()
            return
        }

        let urlString = formulateRequest(initialUrl: WebManager.initialURL)
        guard let url = WebManager.policyURL(from: urlString) else {
            showOfflineScreen()
            return
        }

        openPolicyWebView(url: url)
    }

    func onPolicyAccepted() {
        WebManager.acceptPolicy()
        onGameStart()
    }

    func openPolicyWebView(url: URL) {
        let contentView = CustomHostingController(rootView: WebView(url: url, onAccept: { [weak self] in
            self?.onPolicyAccepted()
        }))
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = contentView
        OrientationHelper.orientaionMask = UIInterfaceOrientationMask.all
        OrientationHelper.isAutoRotationEnabled = true
        window?.makeKeyAndVisible()
    }

    func showOfflineScreen() {
        let contentView = CustomHostingController(rootView: OfflinePolicyView())
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = contentView
        OrientationHelper.orientaionMask = UIInterfaceOrientationMask.portrait
        OrientationHelper.isAutoRotationEnabled = false
        window?.makeKeyAndVisible()
    }

    func showLoadingScreen() {
        if let storyboard = UIStoryboard(name: "LaunchScreen", bundle: nil) as? UIStoryboard {
            if let loadingVC = storyboard.instantiateInitialViewController() as? UIViewController {
                self.window = UIWindow(frame: UIScreen.main.bounds)
                self.window?.rootViewController = loadingVC
                self.window?.makeKeyAndVisible()

                if let logo = loadingVC.view.viewWithTag(1) as? UIImageView {
                    let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")

                    pulseAnimation.duration = 1.5
                    pulseAnimation.fromValue = 1
                    pulseAnimation.toValue = 0.8

                    pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    pulseAnimation.autoreverses = true
                    pulseAnimation.repeatCount = .infinity

                    logo.layer.add(pulseAnimation, forKey: "pulse")
                }
            }
        } else {
            print("Error: LaunchScreen storyboard not found")
        }
    }
}
