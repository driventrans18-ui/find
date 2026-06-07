import Foundation
import WebKit

// Loads a URL in a hidden WKWebView (full Safari engine) and returns the
// fully-rendered HTML after JavaScript has run. This bypasses Cloudflare and
// other bot-detection that blocks plain URLSession requests.
func fetchHTMLWithBrowser(url: URL, waitAfterLoad: TimeInterval = 3.0) async throws -> String {
    try await withCheckedThrowingContinuation { cont in
        DispatchQueue.main.async {
            let loader = _WKHTMLFetcher(wait: waitAfterLoad)
            var req = URLRequest(url: url)
            req.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            loader.start(req: req) { result in
                switch result {
                case .success(let html): cont.resume(returning: html)
                case .failure(let err): cont.resume(throwing: err)
                }
            }
        }
    }
}

// Loads a page in WKWebView, injects JS that submits an image file via the
// first <input type="file"> form on the page, then returns the results HTML.
func submitImageFormWithBrowser(
    pageURL: URL,
    imageData: Data,
    waitAfterSubmit: TimeInterval = 6.0
) async throws -> String {
    let base64 = imageData.base64EncodedString()
    let js = """
    (function() {
        var b64 = '\(base64)';
        var bin = atob(b64);
        var bytes = new Uint8Array(bin.length);
        for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
        var blob = new Blob([bytes], {type: 'image/jpeg'});
        var file = new File([blob], 'face.jpg', {type: 'image/jpeg'});
        var dt = new DataTransfer();
        dt.items.add(file);
        var input = document.querySelector('input[type="file"]');
        if (!input) return 'NO_INPUT';
        input.files = dt.files;
        input.dispatchEvent(new Event('change', {bubbles: true}));
        var form = input.closest('form') || document.querySelector('form');
        if (form) { form.submit(); return 'SUBMITTED'; }
        return 'NO_FORM';
    })();
    """

    return try await withCheckedThrowingContinuation { cont in
        DispatchQueue.main.async {
            let loader = _WKHTMLFetcher(wait: waitAfterSubmit)

            // After the initial page loads, inject JS to submit the form,
            // then wait for the results navigation to finish.
            loader.onPageLoad = { webView in
                webView.evaluateJavaScript(js) { _, _ in }
            }

            var req = URLRequest(url: pageURL)
            req.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            loader.start(req: req, waitForSecondNavigation: true) { result in
                switch result {
                case .success(let html): cont.resume(returning: html)
                case .failure(let err): cont.resume(throwing: err)
                }
            }
        }
    }
}

// MARK: - Internal implementation

private final class _WKHTMLFetcher: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    let waitAfterLoad: TimeInterval
    var onPageLoad: ((WKWebView) -> Void)?

    private var completion: ((Result<String, Error>) -> Void)?
    private var navigationCount = 0
    private var waitForSecondNavigation = false
    private var timer: Timer?

    init(wait: TimeInterval) {
        waitAfterLoad = wait
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true
        // Place off-screen so WKWebView actually loads content
        webView = WKWebView(frame: CGRect(x: -2, y: -2, width: 1, height: 1), configuration: cfg)
        super.init()
        webView.navigationDelegate = self
    }

    func start(req: URLRequest, waitForSecondNavigation: Bool = false, completion: @escaping (Result<String, Error>) -> Void) {
        self.completion = completion
        self.waitForSecondNavigation = waitForSecondNavigation
        // Timeout
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
            self?.finish(with: .failure(URLError(.timedOut)))
        }
        webView.load(req)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationCount += 1
        if waitForSecondNavigation && navigationCount == 1 {
            // First load done — inject JS to submit the form
            onPageLoad?(webView)
            // Many modern sites use AJAX/SPA navigation that never fires a second
            // WKNavigation event. Schedule an unconditional extract after the full
            // wait so we always get results even if no second navigation occurs.
            DispatchQueue.main.asyncAfter(deadline: .now() + waitAfterLoad) { [weak self] in
                self?.extract()
            }
            return
        }
        // Second (results) navigation finished — extract after brief JS render time
        DispatchQueue.main.asyncAfter(deadline: .now() + min(waitAfterLoad, 2.0)) { [weak self] in
            self?.extract()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(with: .failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(with: .failure(error))
    }

    private func extract() {
        webView.evaluateJavaScript("document.documentElement.outerHTML") { [weak self] result, error in
            if let html = result as? String {
                self?.finish(with: .success(html))
            } else {
                self?.finish(with: .failure(error ?? URLError(.cannotParseResponse)))
            }
        }
    }

    private func finish(with result: Result<String, Error>) {
        guard let comp = completion else { return }
        completion = nil
        timer?.invalidate()
        timer = nil
        comp(result)
    }
}
