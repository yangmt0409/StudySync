import Foundation
import UIKit
import WebKit

/// Persistent Claude session holder + API fetcher.
///
/// Problem this solves: When a *fresh* WKWebView loads claude.ai, the SPA
/// runs an init check that detects the WebView as "not the login session"
/// and forcibly navigates to `/logout`, invalidating the cookie. This
/// happened even though the cookie store is shared via `.default()`.
///
/// Solution: reuse the *login* WKWebView for all API fetches. After the
/// user logs in successfully via `ClaudeWebLoginView`, we capture that
/// webView here and keep it alive (attached to the key window, invisible)
/// for the lifetime of the app. All subsequent API calls run as in-page
/// `fetch()` inside that exact WebView, so the SPA's auth state is preserved.
@MainActor
final class ClaudeAPIFetcher: NSObject {
    static let shared = ClaudeAPIFetcher()

    /// The login webView, re-parented to the main window so it survives
    /// sheet dismissal. All API fetches run inside this webView.
    private var webView: WKWebView?

    /// Internal log for the most recent fetch.
    private(set) var log: String = ""

    private override init() { super.init() }

    private func addLog(_ msg: String) {
        debugPrint("[ClaudeAPIFetcher] \(msg)")
        log += "  • \(msg)\n"
    }

    // MARK: - Capture (called from ClaudeWebLoginView lifecycle)

    /// Eagerly bind the login webView. Called from `makeUIView` — the webView
    /// is still in SwiftUI's view hierarchy at this point, we just hold a
    /// strong reference so it survives sheet dismissal.
    func bindLoginWebView(_ wv: WKWebView) {
        // Release any previous captured webView
        clearSession()
        self.webView = wv
        debugPrint("[ClaudeAPIFetcher] Bound login webView (still in sheet)")
    }

    /// Called from `dismantleUIView` when the login sheet dismisses.
    /// Re-parents the bound webView to the key window so it stays alive
    /// with its session state intact.
    func reparentToKeyWindow() {
        guard let wv = webView else {
            debugPrint("[ClaudeAPIFetcher] reparent: no bound webView")
            return
        }
        // Remove from whatever parent (probably the sheet view)
        wv.removeFromSuperview()

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            wv.alpha = 0.01
            wv.isUserInteractionEnabled = false
            wv.frame = CGRect(x: -400, y: 0, width: 1, height: 1)
            window.addSubview(wv)
            debugPrint("[ClaudeAPIFetcher] Re-parented to key window at url: \(wv.url?.absoluteString ?? "<nil>")")
        } else {
            debugPrint("[ClaudeAPIFetcher] ⚠️ no key window, webView may be suspended")
        }
    }

    /// Returns whether we have a bound session-ready webView.
    var hasSession: Bool { webView != nil }

    /// Clears the bound session (on logout or re-login).
    func clearSession() {
        webView?.removeFromSuperview()
        webView = nil
    }

    // MARK: - Session Restore

    /// Attempt to restore a Claude session from cookies persisted in
    /// `WKWebsiteDataStore.default()` (survives app restart).
    ///
    /// Flow:
    /// 1. Check that claude.ai session cookies still exist.
    /// 2. Create a hidden WebView, load a blank page with the claude.ai
    ///    origin so `fetch()` can include cookies without triggering the
    ///    SPA's auth-check/logout flow.
    /// 3. Validate by calling `/api/organizations`.
    /// 4. If valid, keep the WebView as the active session.
    func restoreSession() async -> Bool {
        if webView != nil { return true }        // already live

        debugPrint("[ClaudeAPIFetcher] Attempting session restore from persisted cookies…")

        // 1. Quick cookie check — skip network work if nothing is saved.
        let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
        let claudeCookies = cookies.filter { $0.domain.contains("claude.ai") }
        let hasSessionCookie = claudeCookies.contains {
            ($0.name == "sessionKey" ||
             $0.name == "__Secure-next-auth.session-token" ||
             $0.name.lowercased().contains("session")) &&
            !$0.value.isEmpty && $0.value.count > 10
        }

        guard hasSessionCookie else {
            debugPrint("[ClaudeAPIFetcher] ❌ No claude.ai session cookies — cannot restore")
            return false
        }
        debugPrint("[ClaudeAPIFetcher] Found \(claudeCookies.count) claude.ai cookies")

        // 2. Create a hidden WebView on the claude.ai origin.
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        let wv = WKWebView(frame: CGRect(x: -400, y: 0, width: 1, height: 1), configuration: config)
        wv.alpha = 0.01
        wv.isUserInteractionEnabled = false
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            debugPrint("[ClaudeAPIFetcher] ⚠️ no key window for session restore")
            return false
        }
        window.addSubview(wv)

        // Load a blank document whose origin is claude.ai so that fetch()
        // calls include cookies *without* downloading the SPA JavaScript.
        wv.loadHTMLString("<!DOCTYPE html><html><body></body></html>",
                          baseURL: URL(string: "https://claude.ai")!)
        // Give WebKit a moment to commit the navigation.
        try? await Task.sleep(for: .seconds(0.4))

        // 3. Bind temporarily and validate.
        self.webView = wv

        let testURL = URL(string: "https://claude.ai/api/organizations")!
        guard let json = await fetchJSON(from: testURL) else {
            debugPrint("[ClaudeAPIFetcher] ❌ restore failed: fetch returned nil")
            clearSession()
            return false
        }

        if json.contains("\"type\":\"error\"") || json.contains("account_session_invalid") {
            debugPrint("[ClaudeAPIFetcher] ❌ restore failed: server auth error")
            clearSession()
            return false
        }

        debugPrint("[ClaudeAPIFetcher] ✅ Session restored from persisted cookies!")
        return true
    }

    // MARK: - Fetch

    /// Fetch raw JSON text from a Claude API endpoint using the captured login webView.
    /// Returns nil if no session is captured or the request fails.
    func fetchJSON(from url: URL) async -> String? {
        self.log = ""
        addLog("target: \(url.absoluteString)")

        guard let wv = webView else {
            addLog("❌ no captured webView — user must log in first")
            return nil
        }
        addLog("using captured webView, currently at: \(wv.url?.absoluteString ?? "<nil>")")

        // The body passed to callAsyncJavaScript is a function body (no wrapper needed).
        // It awaits a fetch() call and returns status + body.
        let script = """
        try {
            const r = await fetch(targetUrl, {
                credentials: 'include',
                headers: { 'Accept': 'application/json' }
            });
            const text = await r.text();
            return JSON.stringify({ status: r.status, body: text });
        } catch (e) {
            return JSON.stringify({ status: -1, body: 'ERROR: ' + String(e && e.message || e) });
        }
        """

        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            wv.callAsyncJavaScript(
                script,
                arguments: ["targetUrl": url.absoluteString],
                in: nil,
                in: .page
            ) { [weak self] result in
                Task { @MainActor in
                    guard let self else {
                        cont.resume(returning: nil)
                        return
                    }
                    switch result {
                    case .success(let value):
                        let json = self.parseFetchResult(value)
                        cont.resume(returning: json)
                    case .failure(let error):
                        self.addLog("❌ callAsyncJavaScript error: \(error.localizedDescription)")
                        cont.resume(returning: nil)
                    }
                }
            }
        }
    }

    private func parseFetchResult(_ value: Any?) -> String? {
        guard let str = value as? String,
              let data = str.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            addLog("❌ JS result not parseable: \(String(describing: value).prefix(200))")
            return nil
        }

        let status = (obj["status"] as? Int) ?? -1
        let body = (obj["body"] as? String) ?? ""
        addLog("HTTP \(status), body len=\(body.count)")

        if status == 200 {
            return body
        }
        if status == 401 || status == 403 {
            addLog("auth error body: \(body.prefix(200))")
            // Return body so caller can detect error envelope
            return body.isEmpty ? nil : body
        }
        if status == -1 {
            addLog("js/network error: \(body.prefix(200))")
            return nil
        }
        addLog("non-200 body preview: \(body.prefix(200))")
        return body.isEmpty ? nil : body
    }
}
