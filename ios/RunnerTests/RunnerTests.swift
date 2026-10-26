import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  private func cookie(domain: String = ".chaoxing.com", path: String = "/",
                      secure: Bool = false, expires: Date? = nil) -> HTTPCookie {
    var properties: [HTTPCookiePropertyKey: Any] = [
      .name: "session", .value: "test", .domain: domain, .path: path,
    ]
    if secure { properties[.secure] = "TRUE" }
    if let expires = expires { properties[.expires] = expires }
    return HTTPCookie(properties: properties)!
  }

  func testCookieDomainDoesNotLeakToUnrelatedHosts() {
    let session = cookie()
    XCTAssertTrue(WebCookieBridge.matches(session, url: URL(string: "https://i.chaoxing.com/")!))
    XCTAssertTrue(WebCookieBridge.matches(session, url: URL(string: "https://chaoxing.com/")!))
    XCTAssertFalse(WebCookieBridge.matches(session, url: URL(string: "https://evilchaoxing.com/")!))
    XCTAssertFalse(WebCookieBridge.matches(session, url: URL(string: "https://chaoxing.com.evil.test/")!))
    XCTAssertFalse(WebCookieBridge.matches(cookie(domain: "i.chaoxing.com"),
      url: URL(string: "https://mooc1.chaoxing.com/")!))
  }

  func testCookiePathUsesDirectoryBoundary() {
    let session = cookie(path: "/course")
    XCTAssertTrue(WebCookieBridge.matches(session, url: URL(string: "https://i.chaoxing.com/course")!))
    XCTAssertTrue(WebCookieBridge.matches(session, url: URL(string: "https://i.chaoxing.com/course/1")!))
    XCTAssertFalse(WebCookieBridge.matches(session, url: URL(string: "https://i.chaoxing.com/courses")!))
    XCTAssertFalse(WebCookieBridge.matches(session, url: URL(string: "https://i.chaoxing.com/")!))
  }

  func testExpiredAndSecureCookies() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let https = URL(string: "https://i.chaoxing.com/")!
    XCTAssertFalse(WebCookieBridge.matches(cookie(expires: now.addingTimeInterval(-10)),
      url: https, now: now))
    XCTAssertTrue(WebCookieBridge.matches(cookie(expires: now.addingTimeInterval(10)),
      url: https, now: now))
    XCTAssertTrue(WebCookieBridge.matches(cookie(secure: true), url: https, now: now))
    XCTAssertFalse(WebCookieBridge.matches(cookie(secure: true),
      url: URL(string: "http://i.chaoxing.com/")!, now: now))
  }
}
