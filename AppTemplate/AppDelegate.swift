import UIKit
import SwiftUI

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var application: UIApplication?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        self.application = application
        showLoadingScreen()
        initApp()
        return true
    }
    
    func onGameStart() {
        let contentView = CustomHostingController(rootView: BDBettingTipsApp())
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = contentView

        OrientationHelper.orientaionMask = UIInterfaceOrientationMask.portrait
        OrientationHelper.isAutoRotationEnabled = false

        window?.makeKeyAndVisible()
    }
}

class CustomHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return OrientationHelper.orientaionMask
    }

    override var shouldAutorotate: Bool {
        return OrientationHelper.isAutoRotationEnabled
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
}

class OrientationHelper {
    public static var orientaionMask: UIInterfaceOrientationMask = .portrait
    public static var isAutoRotationEnabled: Bool = false
}
