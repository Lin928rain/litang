import Flutter
import UIKit
import UserNotifications
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var cookieChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "litang/web_cookies",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      WebCookieBridge.handle(call, result: result)
    }
    cookieChannel = channel
  }
}

/// webview_flutter uses the default WKWebsiteDataStore unless configured otherwise.
/// Read HttpOnly cookies natively; JavaScript cannot access the login session.
enum WebCookieBridge {
  static let defaultURLs = [
    "https://i.chaoxing.com/", "https://passport2.chaoxing.com/",
    "https://mooc1.chaoxing.com/", "https://mooc2-ans.chaoxing.com/",
  ]

  static func matchesHost(_ cookie: HTTPCookie, url: URL) -> Bool {
    guard let host = url.host?.lowercased() else { return false }
    let domain = cookie.domain.lowercased()
    if domain.hasPrefix(".") {
      return host == String(domain.dropFirst()) || host.hasSuffix(domain)
    }
    return host == domain
  }

  static func matches(_ cookie: HTTPCookie, url: URL, now: Date = Date()) -> Bool {
    guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
      matchesHost(cookie, url: url),
      !cookie.isSecure || url.scheme?.lowercased() == "https",
      cookie.expiresDate.map({ $0 > now }) ?? true
    else { return false }
    let path = url.path.isEmpty ? "/" : url.path
    return path == cookie.path
      || path.hasPrefix(cookie.path.hasSuffix("/") ? cookie.path : cookie.path + "/")
  }

  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "readCookies" || call.method == "read" || call.method == "clear" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let args = call.arguments as? [String: Any]
    let urls = (args?["urls"] as? [String] ?? defaultURLs).compactMap(URL.init(string:))
    DispatchQueue.main.async {
      let store = WKWebsiteDataStore.default().httpCookieStore
      store.getAllCookies { cookies in
        if call.method == "clear" {
          // Clear every path for the requested hosts, without logging out school WebViews.
          let group = DispatchGroup()
          for cookie in cookies where urls.contains(where: { matchesHost(cookie, url: $0) }) {
            group.enter()
            store.delete(cookie) { group.leave() }
          }
          group.notify(queue: .main) { result(nil) }
          return
        }
        let matching = cookies.filter { cookie in
          urls.contains(where: { matches(cookie, url: $0) })
        }.sorted { $0.path.count > $1.path.count }
        if call.method == "readCookies" {
          // Preserve host-only/domain cookies and paths; never widen their scope in Dart.
          result(matching.map { cookie in
            ["name": cookie.name, "value": cookie.value,
             "domain": cookie.domain, "path": cookie.path]
          })
        } else {
          var headers: [String: String] = [:]
          for url in urls {
            let values = matching.filter { matches($0, url: url) }
              .map { "\($0.name)=\($0.value)" }
            if !values.isEmpty { headers[url.absoluteString] = values.joined(separator: "; ") }
          }
          result(headers)
        }
      }
    }
  }
}
