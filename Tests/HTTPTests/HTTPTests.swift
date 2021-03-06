import HTTP
import XCTest

class HTTPTests: XCTestCase {
    func testCookieParse() throws {
        /// from https://developer.mozilla.org/en-US/docs/Web/HTTP/Cookies
        guard let (name, value) = HTTPCookieValue.parse("id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Secure; HttpOnly") else {
            throw HTTPError(identifier: "cookie", reason: "Could not parse test cookie")
        }

        XCTAssertEqual(name, "id")
        XCTAssertEqual(value.expires, Date(rfc1123: "Wed, 21 Oct 2015 07:28:00 GMT"))
        XCTAssertEqual(value.isSecure, true)
        XCTAssertEqual(value.isHTTPOnly, true)
    }
    
    func testCookieIsSerializedCorrectly() throws {
        var httpReq = HTTPRequest(method: .GET, url: "/")

        guard let (name, value) = HTTPCookieValue.parse("id=value; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Secure; HttpOnly") else {
            throw HTTPError(identifier: "cookie", reason: "Could not parse test cookie")
        }
        
        httpReq.cookies = HTTPCookies(dictionaryLiteral: (name, value))
        
        XCTAssertEqual(httpReq.headers.firstValue(name: .cookie), "id=value")
    }

    func testAcceptHeader() throws {
        let httpReq = HTTPRequest(method: .GET, url: "/", headers: ["Accept": "text/html, application/json, application/xml;q=0.9, */*;q=0.8"])
        XCTAssertTrue(httpReq.accept.mediaTypes.contains(.html))
        XCTAssertEqual(httpReq.accept.comparePreference(for: .html, to: .xml), .orderedAscending)
        XCTAssertEqual(httpReq.accept.comparePreference(for: .plainText, to: .html), .orderedDescending)
        XCTAssertEqual(httpReq.accept.comparePreference(for: .html, to: .json), .orderedSame)
    }

    func testRemotePeer() throws {
        let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let client = try HTTPClient.connect(hostname: "httpbin.org", on: worker).wait()
        let httpReq = HTTPRequest(method: .GET, url: "/")
        let httpRes = try client.send(httpReq).wait()
        XCTAssertEqual(httpRes.remotePeer.port, 80)
    }
    
    func testLargeResponseClose() throws {
        struct LargeResponder: HTTPServerResponder {
            func respond(to request: HTTPRequest, on worker: Worker) -> EventLoopFuture<HTTPResponse> {
                let res = HTTPResponse(
                    status: .ok,
                    body: String(repeating: "0", count: 2_000_000)
                )
                return worker.future(res)
            }
        }
        let worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let server = try HTTPServer.start(
            hostname: "localhost",
            port: 8080,
            responder: LargeResponder(),
            on: worker
        ) { error in
            XCTFail("\(error)")
        }.wait()
        
        let client = try HTTPClient.connect(hostname: "localhost", port: 8080, on: worker).wait()
        var req = HTTPRequest(method: .GET, url: "/")
        req.headers.replaceOrAdd(name: .connection, value: "close")
        let res = try client.send(req).wait()
        XCTAssertEqual(res.body.count, 2_000_000)
        try server.close().wait()
        try server.onClose.wait()
    }

    static let allTests = [
        ("testCookieParse", testCookieParse),
        ("testAcceptHeader", testAcceptHeader),
        ("testRemotePeer", testRemotePeer),
        ("testCookieIsSerializedCorrectly", testCookieIsSerializedCorrectly),
        ("testLargeResponseClose", testLargeResponseClose),
    ]
}
