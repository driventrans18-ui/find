import SwiftUI
import WebKit

// Makes URL usable with .sheet(item:)
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

// MARK: - Sheet trigger

struct InAppBrowser: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            _WebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - WKWebView wrapper

private struct _WebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> _BrowserContainer {
        let container = _BrowserContainer()
        container.load(url)
        context.coordinator.container = container
        return container
    }

    func updateUIView(_ uiView: _BrowserContainer, context: Context) {}

    final class Coordinator {
        var container: _BrowserContainer?
    }
}

// MARK: - Container: WKWebView + toolbar

final class _BrowserContainer: UIView {
    private let webView: WKWebView
    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private let toolbar = UIToolbar()
    private let backButton = UIBarButtonItem(systemItem: .rewind)
    private let forwardButton = UIBarButtonItem(systemItem: .fastForward)
    private let refreshButton = UIBarButtonItem(systemItem: .refresh)
    private let shareButton = UIBarButtonItem(systemItem: .action)
    private let urlLabel = UILabel()

    private var progressObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?
    private var canGoBackObservation: NSKeyValueObservation?
    private var canGoForwardObservation: NSKeyValueObservation?

    override init(frame: CGRect) {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        webView = WKWebView(frame: .zero, configuration: config)
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    // MARK: - Setup

    private func setup() {
        backgroundColor = UIColor(white: 0.07, alpha: 1)

        // URL label
        urlLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        urlLabel.textColor = UIColor.secondaryLabel
        urlLabel.textAlignment = .center
        urlLabel.lineBreakMode = .byTruncatingMiddle

        // Progress bar
        progressBar.progressTintColor = .systemBlue
        progressBar.trackTintColor = .clear

        // Toolbar
        toolbar.barStyle = .black
        toolbar.isTranslucent = false
        backButton.target = self; backButton.action = #selector(goBack)
        forwardButton.target = self; forwardButton.action = #selector(goForward)
        refreshButton.target = self; refreshButton.action = #selector(reload)
        shareButton.target = self; shareButton.action = #selector(share)
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let urlItem = UIBarButtonItem(customView: urlLabel)
        urlLabel.widthAnchor.constraint(equalToConstant: 200).isActive = true
        toolbar.items = [backButton, forwardButton, flex, urlItem, flex, shareButton, refreshButton]

        // Subviews
        [webView, progressBar, toolbar].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),

            progressBar.topAnchor.constraint(equalTo: topAnchor),
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 2),

            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor)
        ])

        // KVO
        progressObservation = webView.observe(\.estimatedProgress) { [weak self] wv, _ in
            let p = Float(wv.estimatedProgress)
            self?.progressBar.setProgress(p, animated: true)
            self?.progressBar.isHidden = p >= 1.0
        }
        urlObservation = webView.observe(\.url) { [weak self] wv, _ in
            self?.urlLabel.text = wv.url?.host ?? ""
        }
        canGoBackObservation = webView.observe(\.canGoBack) { [weak self] wv, _ in
            self?.backButton.isEnabled = wv.canGoBack
        }
        canGoForwardObservation = webView.observe(\.canGoForward) { [weak self] wv, _ in
            self?.forwardButton.isEnabled = wv.canGoForward
        }
        backButton.isEnabled = false
        forwardButton.isEnabled = false
    }

    // MARK: - Actions

    @objc private func goBack() { webView.goBack() }
    @objc private func goForward() { webView.goForward() }
    @objc private func reload() { webView.reload() }

    @objc private func share() {
        guard let url = webView.url else { return }
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        parentViewController?.present(vc, animated: true)
    }

    private var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}
