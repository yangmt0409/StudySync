import Foundation
import WebKit

/// Loads a URL in a hidden WKWebView, injects JavaScript, and returns the result.
@MainActor
final class AIWebScraper: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<String?, Never>?
    private var jsScript: String = ""
    private var waitSeconds: Double = 3.0
    private var retryCount = 0
    private let maxRetries = 3
    private var isFinished = false
    private var isInjecting = false

    func scrape(url: URL, javascript: String, waitSeconds: Double = 3.0) async -> String? {
        self.jsScript = javascript
        self.waitSeconds = waitSeconds
        self.retryCount = 0
        self.isFinished = false
        self.isInjecting = false

        return await withCheckedContinuation { cont in
            self.continuation = cont

            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default()

            let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 812), configuration: config)
            wv.navigationDelegate = self
            wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

            // Attach to window (required for WKWebView to actually load)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first {
                wv.alpha = 0.01
                wv.frame = CGRect(x: -400, y: 0, width: 375, height: 812)
                window.addSubview(wv)
            }

            self.webView = wv
            wv.load(URLRequest(url: url))

            // Timeout after 25s (SPAs may need extra time)
            DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
                self?.finish(result: nil)
            }
        }
    }

    // MARK: - WKNavigationDelegate

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            // Wait for JS rendering (SPAs need time)
            try? await Task.sleep(for: .seconds(self.waitSeconds))
            injectScript()
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            debugPrint("[AIWebScraper] Navigation failed: \(error.localizedDescription)")
            finish(result: nil)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            debugPrint("[AIWebScraper] Provisional navigation failed: \(error.localizedDescription)")
            finish(result: nil)
        }
    }

    // MARK: - JS Injection

    private func injectScript() {
        guard let wv = webView, !isFinished, !isInjecting else { return }
        isInjecting = true

        wv.evaluateJavaScript(jsScript) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                self.isInjecting = false
                if let json = result as? String, !json.isEmpty, json != "null" {
                    self.finish(result: json)
                } else if self.retryCount < self.maxRetries && !self.isFinished {
                    // Retry after a short wait (page might still be loading)
                    self.retryCount += 1
                    if let error {
                        debugPrint("[AIWebScraper] JS injection error (retry \(self.retryCount)/\(self.maxRetries)): \(error.localizedDescription)")
                    } else {
                        debugPrint("[AIWebScraper] JS returned null/empty (retry \(self.retryCount)/\(self.maxRetries))")
                    }
                    try? await Task.sleep(for: .seconds(2))
                    self.injectScript()
                } else {
                    if let error {
                        debugPrint("[AIWebScraper] JS injection final error: \(error.localizedDescription)")
                    }
                    self.finish(result: nil)
                }
            }
        }
    }

    private func finish(result: String?) {
        guard !isFinished else { return }
        isFinished = true
        webView?.removeFromSuperview()
        webView = nil
        if let cont = continuation {
            continuation = nil
            cont.resume(returning: result)
        }
    }
}

// MARK: - Scrape Scripts

enum AIScrapeScript {

    /// ChatGPT internal API scraper — fetches plan, email, Codex usage, rate-limit status
    static let chatGPT = """
    (function() {
        var result = {plan: null, email: null, loggedIn: false, rateLimited: false,
                      codexTasksUsed: null, codexTasksLimit: null, snippet: null};
        var fetchOpts = {credentials: 'include'};

        // Step 1: Try /backend-api/me for user info
        return fetch('/backend-api/me', fetchOpts)
        .then(function(r) {
            if (!r.ok) throw new Error('me-status-' + r.status);
            return r.json();
        })
        .then(function(me) {
            result.loggedIn = true;
            result.email = me.email || (me.emails && me.emails[0]) || null;
            if (me.plan_type) result.plan = me.plan_type;
        })
        .catch(function() {})
        .then(function() {
            // Step 2: Try /backend-api/accounts/check for plan + entitlements
            return fetch('/backend-api/accounts/check', fetchOpts)
                .then(function(r) { return r.ok ? r.json() : null; })
                .then(function(data) {
                    if (!data || !data.accounts) return;
                    result.loggedIn = true;
                    try {
                        var acctKey = data.accounts['default'] ? 'default' : Object.keys(data.accounts)[0];
                        var acct = data.accounts[acctKey];
                        if (acct) {
                            var p = null;
                            if (acct.account) {
                                p = acct.account.subscription_plan || acct.account.plan_type;
                                if (!p && acct.account.has_active_subscription) p = 'Plus';
                                if (!p && acct.account.is_deactivated === false) p = 'Free';
                            }
                            if (!p && acct.entitlement) {
                                p = acct.entitlement.subscription_plan;
                            }
                            if (p) result.plan = p;
                            // Check for rate limits in response
                            if (acct.rate_limits) {
                                var rl = acct.rate_limits;
                                if (rl.is_limited || rl.rate_limited) result.rateLimited = true;
                            }
                        }
                    } catch(e) {}
                })
                .catch(function() {});
        })
        .then(function() {
            // Step 3: Try to get Codex quota/tasks
            return fetch('/backend-api/codex/quota', fetchOpts)
                .then(function(r) { return r.ok ? r.json() : null; })
                .then(function(data) {
                    if (data) {
                        // Try various response shapes
                        if (typeof data.used === 'number' && typeof data.limit === 'number') {
                            result.codexTasksUsed = data.used;
                            result.codexTasksLimit = data.limit;
                        } else if (data.quota) {
                            result.codexTasksUsed = data.quota.used || data.quota.tasks_used || 0;
                            result.codexTasksLimit = data.quota.limit || data.quota.tasks_limit || 0;
                        } else if (typeof data.tasks_remaining === 'number' && typeof data.tasks_limit === 'number') {
                            result.codexTasksLimit = data.tasks_limit;
                            result.codexTasksUsed = data.tasks_limit - data.tasks_remaining;
                        }
                    }
                })
                .catch(function() {
                    // Codex quota endpoint not available, try tasks list
                    return fetch('/backend-api/codex/tasks?limit=1', fetchOpts)
                        .then(function(r) { return r.ok ? r.json() : null; })
                        .then(function(data) {
                            if (data && data.quota) {
                                result.codexTasksUsed = data.quota.used || 0;
                                result.codexTasksLimit = data.quota.limit || 0;
                            }
                        })
                        .catch(function() {});
                });
        })
        .then(function() {
            if (!result.loggedIn) {
                // All API calls failed — check DOM for login state
                var bodyText = document.body ? String(document.body.innerText || '') : '';
                result.snippet = bodyText.substring(0, 500);
                result.loggedIn = bodyText.length > 100 &&
                    !bodyText.match(/log\\s*in|sign\\s*in|create.*account|welcome.*back/i);
            }

            // Normalize plan name
            if (result.plan) {
                var p = String(result.plan).toLowerCase().replace(/[_\\-]/g, '');
                if (p.includes('plus')) result.plan = 'Plus';
                else if (p.includes('pro')) result.plan = 'Pro';
                else if (p.includes('team')) result.plan = 'Team';
                else if (p.includes('enterprise')) result.plan = 'Enterprise';
                else if (p.includes('free')) result.plan = 'Free';
                else {
                    result.plan = result.plan.replace(/plan$/i, '').trim();
                    if (result.plan) result.plan = result.plan.charAt(0).toUpperCase() + result.plan.slice(1);
                }
            }

            // Check page for rate-limit banners (expanded patterns)
            var bodyText = document.body ? String(document.body.innerText || '') : '';
            if (!result.rateLimited) {
                result.rateLimited = !!(
                    bodyText.match(/(?:reached|hit|exceeded).*(?:limit|cap|usage)/i) ||
                    bodyText.match(/(?:limit|cap|usage).*(?:reached|hit|exceeded)/i) ||
                    bodyText.match(/too many (?:requests|messages)/i) ||
                    bodyText.match(/rate[\\s\\-_]*limit/i) ||
                    bodyText.match(/try again (?:in|after|later)/i) ||
                    bodyText.match(/temporarily unavailable/i) ||
                    bodyText.match(/usage cap/i)
                );
            }

            if (!result.snippet) result.snippet = bodyText.substring(0, 500);
            return JSON.stringify(result);
        });
    })()
    """

    /// Gemini / AI Studio rate limit page scraper
    static let gemini = """
    (function() {
        var bodyText = document.body ? String(document.body.innerText || '').trim() : '';
        if (!bodyText || bodyText.length < 30) return null;

        var result = {
            models: [],
            allPercentages: [],
            plan: null,
            loggedIn: true,
            snippet: bodyText.substring(0, 500)
        };

        // Check login state
        if (bodyText.match(/sign\\s*in|log\\s*in/i) && bodyText.length < 300) {
            result.loggedIn = false;
            return JSON.stringify(result);
        }

        var seenModels = {};

        // Strategy 1: Try DOM queries for progress bars and structured elements
        try {
            var bars = document.querySelectorAll('[role="progressbar"], progress, [class*="progress"], [class*="usage"], [class*="quota"]');
            bars.forEach(function(bar) {
                var val = bar.getAttribute('aria-valuenow') || bar.getAttribute('value');
                if (!val && bar.style && bar.style.width) {
                    val = parseFloat(bar.style.width);
                }
                if (val) {
                    var pct = parseFloat(val);
                    if (pct >= 0 && pct <= 100) {
                        result.allPercentages.push(pct);
                    }
                }
            });
        } catch(e) {}

        // Strategy 2: Parse text for model names and usage data
        var lines = bodyText.split('\\n').map(function(l) { return l.trim(); }).filter(function(l) { return l.length > 0; });

        var currentModel = null;
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i];

            // Detect model names (expanded patterns for newer models)
            var modelMatch = line.match(/(gemini[\\s\\-_]?[\\d\\.]+[\\s\\-_]?(?:pro|flash|ultra|nano|lite)?(?:[\\s\\-_]?(?:latest|exp(?:erimental)?|preview|thinking))?)/i);
            if (!modelMatch) {
                modelMatch = line.match(/^((?:Gemini|PaLM|Imagen|Gemma)[\\s\\w\\-\\.]*\\S)/i);
            }
            if (modelMatch) {
                currentModel = modelMatch[1].trim();
            }

            // Detect percentage usage
            var pctMatch = line.match(/(\\d{1,3}(?:\\.\\d+)?)\\s*%/);
            if (pctMatch) {
                var pctVal = parseFloat(pctMatch[1]);
                if (pctVal <= 100) {
                    result.allPercentages.push(pctVal);
                    if (currentModel && !seenModels[currentModel]) {
                        seenModels[currentModel] = true;
                        result.models.push({model: currentModel, usagePercent: pctVal});
                    }
                }
            }

            // Detect fraction: "123 / 500" or "123/500" or "123 of 500"
            var fracMatch = line.match(/([\\d,]+)\\s*(?:\\/|of)\\s*([\\d,]+)/);
            if (fracMatch) {
                var used = parseInt(fracMatch[1].replace(/,/g, ''));
                var total = parseInt(fracMatch[2].replace(/,/g, ''));
                if (total > 0 && used <= total * 2) {
                    var fPct = Math.round(used / total * 100);
                    result.allPercentages.push(fPct);
                    if (currentModel && !seenModels[currentModel]) {
                        seenModels[currentModel] = true;
                        result.models.push({model: currentModel, usagePercent: fPct, used: used, total: total});
                    }
                }
            }
        }

        // Strategy 3: Look for structured data in tables
        try {
            var tables = document.querySelectorAll('table');
            tables.forEach(function(table) {
                var rows = table.querySelectorAll('tr');
                rows.forEach(function(row) {
                    var cells = row.querySelectorAll('td, th');
                    var rowText = row.innerText || '';
                    var mMatch = rowText.match(/(gemini[\\s\\-_]?[\\d\\.]+[\\s\\-_]?\\S*)/i);
                    var pMatch = rowText.match(/(\\d{1,3}(?:\\.\\d+)?)\\s*%/);
                    if (mMatch && pMatch) {
                        var model = mMatch[1].trim();
                        var pct = parseFloat(pMatch[1]);
                        if (!seenModels[model] && pct <= 100) {
                            seenModels[model] = true;
                            result.models.push({model: model, usagePercent: pct});
                            result.allPercentages.push(pct);
                        }
                    }
                });
            });
        } catch(e) {}

        // Detect plan tier
        var planMatch = bodyText.match(/(?:plan|tier)[\\s:]*\\s*(Free|Pay[\\s\\-]?as[\\s\\-]?you[\\s\\-]?go|Paid|Pro|Ultra|Basic|Standard|Premium)/i);
        if (planMatch) {
            result.plan = planMatch[1];
        } else {
            var simplePlan = bodyText.match(/(Free tier|Free plan|Pay as you go|Paid plan)/i);
            if (simplePlan) result.plan = simplePlan[1];
        }

        return JSON.stringify(result);
    })()
    """
}
