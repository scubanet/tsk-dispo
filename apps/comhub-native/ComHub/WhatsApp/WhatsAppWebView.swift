import SwiftUI
import WebKit

/// Plattform-Wrapper um `WKWebView`, der WhatsApp Web laedt. Setzt einen
/// Desktop-User-Agent (sonst lehnt WhatsApp den Browser ab) und nutzt den
/// persistenten Standard-Datastore, damit der QR-Login App-Neustarts ueberlebt.
struct WhatsAppWebView {
  /// Steuerung von aussen (Neu laden).
  @MainActor final class Coordinator {
    weak var webView: WKWebView?
    func reload() { webView?.reload() }
  }
  let coordinator: Coordinator

  private static let desktopUA =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " +
    "(KHTML, like Gecko) Version/17.0 Safari/605.1.15"
  private static let url = URL(string: "https://web.whatsapp.com")!

  @MainActor private func makeWebView() -> WKWebView {
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .default()   // persistent -> Session bleibt
    let webView = WKWebView(frame: .zero, configuration: config)
    webView.customUserAgent = Self.desktopUA
    webView.load(URLRequest(url: Self.url))
    coordinator.webView = webView
    return webView
  }
}

#if os(macOS)
import AppKit
extension WhatsAppWebView: NSViewRepresentable {
  func makeCoordinator() -> Coordinator { coordinator }
  func makeNSView(context: Context) -> WKWebView { makeWebView() }
  func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#else
import UIKit
extension WhatsAppWebView: UIViewRepresentable {
  func makeCoordinator() -> Coordinator { coordinator }
  func makeUIView(context: Context) -> WKWebView { makeWebView() }
  func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#endif
