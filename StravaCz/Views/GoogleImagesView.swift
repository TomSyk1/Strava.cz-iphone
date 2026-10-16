import SwiftUI
import WebKit

struct ImageQuery: Identifiable {
    let id = UUID()
    let name: String
}

/// Sheet s výsledky Google Obrázků pro dané jídlo.
struct GoogleImagesSheet: View {
    let query: String
    @Environment(\.dismiss) private var dismiss

    private var url: URL {
        var components = URLComponents(string: "https://www.google.com/search") ?? URLComponents()
        components.queryItems = [URLQueryItem(name: "tbm", value: "isch"), URLQueryItem(name: "q", value: query)]
        return components.url ?? URL(string: "https://www.google.com")!
    }

    var body: some View {
        NavigationStack {
            GoogleImagesWebView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Obrázky: \(query)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Zavřít") { dismiss() } }
                }
        }
    }
}

private struct GoogleImagesWebView: UIViewRepresentable {
    let url: URL

    // Souhlas s cookies (SOCS) a skrytí consent dialogu – stejné jako v Android verzi.
    private static let consentCookie = "CAESHAgBEhJib3FfaWRlbnRpdHlmcm9udGVuZHVpc2VydmVyXzIwMjMwMzA3LjA2X3AxGgJjcyACGgYIgI_qnwY"

    private static let cleanupScript = #"""
    (function() {
        var style = document.createElement('style');
        style.innerHTML = 'div[role="dialog"], c-wiz[role="dialog"], form[action*="consent"], #lb, div[aria-modal="true"], .fc-consent-root { display: none !important; } html, body { overflow: auto !important; position: static !important; }';
        (document.head || document.documentElement).appendChild(style);
        var btns = document.querySelectorAll('button, form button, input[type="submit"]');
        for (var i = 0; i < btns.length; i++) {
            var txt = (btns[i].innerText || btns[i].value || '').toLowerCase();
            if (txt.includes('přijmout') || txt.includes('accept') || txt.includes('souhlas') || txt.includes('agree')) {
                btns[i].click();
                break;
            }
        }
    })();
    """#

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        let cookies: [HTTPCookie] = [".google.com", ".google.cz"].compactMap { domain in
            HTTPCookie(properties: [
                .name: "SOCS",
                .value: Self.consentCookie,
                .domain: domain,
                .path: "/",
                .secure: "TRUE",
            ])
        }
        let request = URLRequest(url: url)
        var remaining = cookies.count
        if remaining == 0 {
            webView.load(request)
        } else {
            for cookie in cookies {
                config.websiteDataStore.httpCookieStore.setCookie(cookie) {
                    remaining -= 1
                    if remaining == 0 { webView.load(request) }
                }
            }
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript(GoogleImagesWebView.cleanupScript, completionHandler: nil)
        }
    }
}
