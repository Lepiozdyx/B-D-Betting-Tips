import Foundation
import Network
import UIKit

public class WebManager {
    static let initialURL = "https://pdbettingteps.pro/policy"
    static let policyAcceptedKey = "policyAccepted"

    static var isPolicyAccepted: Bool {
        UserDefaults.standard.bool(forKey: policyAcceptedKey)
    }

    static func acceptPolicy() {
        UserDefaults.standard.set(true, forKey: policyAcceptedKey)
    }

    static func policyURL(from urlString: String) -> URL? {
        URL(string: urlString)
    }

    static func isInternetAvailable() -> Bool {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        let semaphore = DispatchSemaphore(value: 0)
        var isConnected = false

        monitor.pathUpdateHandler = { path in
            isConnected = path.status == .satisfied
            semaphore.signal()
            monitor.cancel()
        }

        monitor.start(queue: queue)
        _ = semaphore.wait(timeout: .now() + 2)
        return isConnected
    }

    static func safariUserAgent() -> String {
        let version = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(version) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    }
}
