import SwiftUI
import WebKit

struct ClaudeWebLoginView: UIViewRepresentable {
    /// Returns the full serialized cookie string for all claude.ai cookies
    let onSessionObtained: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSessionObtained: onSessionObtained)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

        // Eagerly bind: store a strong reference now so this webView
        // survives sheet dismissal regardless of how the user exits.
        Task { @MainActor in
            ClaudeAPIFetcher.shared.bindLoginWebView(webView)
        }

        let url = URL(string: "https://claude.ai/login")!
        webView.load(URLRequest(url: url))

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        // Before SwiftUI tears down the view hierarchy, move the webView to
        // the key window so it stays alive with its session state intact.
        Task { @MainActor in
            ClaudeAPIFetcher.shared.reparentToKeyWindow()
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onSessionObtained: (String) -> Void
        private var hasCompleted = false
        private var pollTimer: Timer?

        init(onSessionObtained: @escaping (String) -> Void) {
            self.onSessionObtained = onSessionObtained
        }

        deinit {
            pollTimer?.invalidate()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            checkForSession(in: webView)

            // If user navigated past login, start polling
            if let url = webView.url?.absoluteString,
               url.contains("claude.ai"),
               !url.contains("/login"),
               !url.contains("/signup") {
                startPolling(webView: webView)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            checkForSession(in: webView)
            return .allow
        }

        private func startPolling(webView: WKWebView) {
            guard pollTimer == nil, !hasCompleted else { return }
            pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self, weak webView] _ in
                guard let self, let webView, !self.hasCompleted else {
                    self?.pollTimer?.invalidate()
                    self?.pollTimer = nil
                    return
                }
                self.checkForSession(in: webView)
            }
        }

        private func checkForSession(in webView: WKWebView) {
            guard !hasCompleted else { return }

            // CRITICAL: require the webView to have navigated PAST /login and /signup.
            // Otherwise stale cookies from a prior (expired) session would trigger
            // premature capture of a still-logged-out webView.
            let currentURL = webView.url?.absoluteString ?? ""
            guard !currentURL.isEmpty,
                  currentURL.contains("claude.ai"),
                  !currentURL.contains("/login"),
                  !currentURL.contains("/signup"),
                  !currentURL.contains("/logout") else {
                return
            }

            let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
            cookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.hasCompleted else { return }

                let claudeCookies = cookies.filter { $0.domain.contains("claude.ai") }

                // Need at least one session-like cookie to proceed
                let hasSession = claudeCookies.contains(where: {
                    ($0.name == "sessionKey" ||
                     $0.name == "__Secure-next-auth.session-token" ||
                     $0.name.lowercased().contains("session")) &&
                    !$0.value.isEmpty && $0.value.count > 10
                })

                if hasSession {
                    // Serialize ALL claude.ai cookies for API use.
                    // (The webView itself was already bound eagerly in makeUIView,
                    // so we don't need to capture it here — just trigger completion.)
                    let cookieString = claudeCookies
                        .filter { !$0.value.isEmpty }
                        .map { "\($0.name)=\($0.value)" }
                        .joined(separator: "; ")
                    self.complete(with: cookieString)
                }
            }
        }

        private func complete(with cookies: String) {
            guard !hasCompleted else { return }
            hasCompleted = true
            pollTimer?.invalidate()
            pollTimer = nil
            DispatchQueue.main.async {
                self.onSessionObtained(cookies)
            }
        }
    }
}

// MARK: - Generic WebView for OpenAI / Google usage pages

struct AIWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
