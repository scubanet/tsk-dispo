import Foundation

final class MockURLProtocol: URLProtocol {
  nonisolated(unsafe) static var responder: ((URLRequest) -> (Data, Int))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
  override func startLoading() {
    let (data, status) = Self.responder?(request) ?? (Data(), 500)
    let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}

  static func session() -> URLSession {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: cfg)
  }
}
