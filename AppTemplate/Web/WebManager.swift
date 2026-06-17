import Foundation
import UIKit

public class WebManager {
    static let initialURL = "https://pdbettingteps.pro/play"
    static let savedUrlKey = "savedUrl"
    static var provenUrl : URL?
    
    static func decide(finalUrl: String) async -> String {
        print("testing URL: \(finalUrl)")
        let savedUrl = getSavedUrl()
        if savedUrl == "" {
            do {
                if let _ = try await checkInitURL(url: URL(string: finalUrl)!) {
                    trySetSavedUrl(URL(string: finalUrl)!)
                    provenUrl = URL(string: finalUrl)
                    return finalUrl
                } else {
                    return ""
                }
            } catch {
                return ""
            }
        } else {
            if let url = URL(string: savedUrl) {
                provenUrl = url
            }
            return savedUrl
        }
    }
    
    static func checkInitURL(url: URL) async throws -> URL? {
        var request = URLRequest(url: url)
        request.setValue(getUAgent(forWebView: false), forHTTPHeaderField: "User-Agent")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return nil
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            return nil
        }

        guard let finalURL = httpResponse.url else {
            return nil
        }

        return finalURL
    }
    
    static func getSavedUrl() -> String {
        let storage = UserDefaults.standard
        if let urlString = storage.string(forKey: savedUrlKey) {
                if let url = URL(string: urlString) {
                    print("URL loaded: \(urlString)")
                    return urlString
                } else {
                    print("Failed to load URL: \(urlString)")
                    return ""
                }
            } else {
                print("Failed to load URL")
                return ""
            }
    }
    
    static func trySetSavedUrl(_ url: URL) {
        guard !isInvalidURL(url) else {
            return
        }
        
        UserDefaults.standard.set(url.absoluteString, forKey: savedUrlKey)
        provenUrl = url
    }
    
    private static func isInvalidURL(_ url: URL) -> Bool {
        let invalidURLs = ["about:blank", "about:srcdoc"]
        
        if invalidURLs.contains(url.absoluteString) {
            return true
        }
        
        return false
    }
    
    static func getUAgent(forWebView: Bool = false) -> String {
        if forWebView {
            let version = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
            let agent = "Mozilla/5.0 (iPhone; CPU iPhone OS \(version) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
            return agent
        } else {
            let agent = "TestRequest/1.0 CFNetwork/1410.0.3 Darwin/22.4.0"
            return agent
        }
    }
}
