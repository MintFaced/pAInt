//
//  EmailSignupViewController.swift
//  pAInt
//
//  Google Forms email signup screen
//  Styled to match the app's dark aesthetic
//

import UIKit
import WebKit

class EmailSignupViewController: UIViewController {

    // MARK: - Properties

    private var webView: WKWebView!
    private var closeButton: UIButton!
    private var activityIndicator: UIActivityIndicatorView!

    // TODO: Replace with your actual Google Form URL
    private let googleFormURL = "https://docs.google.com/forms/d/e/YOUR_FORM_ID/viewform?embedded=true"

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        loadForm()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.059, green: 0.059, blue: 0.059, alpha: 1.0) // #0F0F0F

        // Configure WebView
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.backgroundColor = UIColor(red: 0.059, green: 0.059, blue: 0.059, alpha: 1.0)
        webView.isOpaque = false
        view.addSubview(webView)

        // Close Button
        closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor(red: 0.33, green: 0.31, blue: 0.36, alpha: 0.85)
        closeButton.layer.cornerRadius = 20
        closeButton.layer.borderWidth = 1
        closeButton.layer.borderColor = UIColor(white: 1.0, alpha: 0.15).cgColor
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        // Activity Indicator
        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .white
        view.addSubview(activityIndicator)

        // Constraints
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func loadForm() {
        activityIndicator.startAnimating()

        guard let url = URL(string: googleFormURL) else {
            NSLog("❌ Invalid Google Form URL")
            showError()
            return
        }

        let request = URLRequest(url: url)
        webView.load(request)

        NSLog("📧 Loading Google Form: %@", googleFormURL)
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func showError() {
        activityIndicator.stopAnimating()

        let alert = UIAlertController(
            title: "Unable to Load Form",
            message: "Please check your internet connection and try again.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Close", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })

        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate

extension EmailSignupViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
        NSLog("✅ Google Form loaded successfully")

        // Inject CSS to match app styling (dark theme)
        let darkCSS = """
        document.body.style.backgroundColor = '#0F0F0F';
        document.body.style.color = '#FFFFFF';
        var inputs = document.querySelectorAll('input, textarea');
        for (var i = 0; i < inputs.length; i++) {
            inputs[i].style.backgroundColor = '#2A2A2A';
            inputs[i].style.color = '#FFFFFF';
            inputs[i].style.borderColor = '#4A4A4A';
        }
        """

        webView.evaluateJavaScript(darkCSS) { _, error in
            if let error = error {
                NSLog("⚠️ CSS injection failed: %@", error.localizedDescription)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("❌ Form load failed: %@", error.localizedDescription)
        showError()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("❌ Form load failed: %@", error.localizedDescription)
        showError()
    }
}
