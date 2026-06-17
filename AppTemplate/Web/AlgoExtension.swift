import Foundation
import UIKit
import AppTrackingTransparency

extension AppDelegate : UNUserNotificationCenterDelegate {
    
    func decide() async -> Bool {
        await WebManager.decide(finalUrl: formulateRequest(initialUrl: WebManager.initialURL))
        return WebManager.provenUrl != nil
    }
    
    func onPositivelyDecided() {
        let contentView = CustomHostingController(rootView: WebView(url: WebManager.provenUrl!))
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = contentView
        OrientationHelper.orientaionMask = UIInterfaceOrientationMask.all
        OrientationHelper.isAutoRotationEnabled = true
        window?.makeKeyAndVisible()
    }
    
    func formulateRequest(initialUrl: String) async -> String {
        let result = initialUrl
        return result
    }
    
    func initApp() {
        self.applyDecision()
    }
    
    func applyDecision() {
        Task {
            if await !decide() {
                self.onGameStart()
            } else {
                self.onPositivelyDecided()
            }
        }
    }
    
    func showLoadingScreen() {
        DispatchQueue.main.async {
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
}
