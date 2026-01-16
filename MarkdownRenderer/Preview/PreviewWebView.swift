import AppKit
import SwiftUI
import WebKit

@MainActor
final class PreviewController: ObservableObject {
	weak var webView: WKWebView?

	func setBodyHTML(_ html: String) {
		guard let webView else { return }
		guard let json = try? String(data: JSONEncoder().encode(html), encoding: .utf8) else { return }
		webView.evaluateJavaScript("window.__setBody(\(json));")
	}

	func scrollTo(progress: Double) {
		guard let webView else { return }
		let clamped = min(max(progress, 0), 1)
		webView.evaluateJavaScript("window.__scrollToProgress(\(clamped));")
	}
}

struct PreviewWebView: NSViewRepresentable {
	let controller: PreviewController
	let markdown: String
	let baseURL: URL?

	func makeNSView(context: Context) -> WKWebView {
		let webView = WKWebView(frame: .zero, configuration: context.coordinator.makeConfiguration())
		webView.navigationDelegate = context.coordinator
		webView.setValue(false, forKey: "drawsBackground")
		controller.webView = webView
		webView.loadHTMLString(wrapHTML(body: MarkdownHTMLRenderer.render(markdown: markdown), baseURL: baseURL), baseURL: baseURL)
		return webView
	}

	func updateNSView(_ nsView: WKWebView, context: Context) {
		context.coordinator.update(webView: nsView, controller: controller, markdown: markdown, baseURL: baseURL)
	}

	func makeCoordinator() -> Coordinator {
		Coordinator()
	}

	private func wrapHTML(body: String, baseURL: URL?) -> String {
		let baseHref = baseURL.map { "<base href=\"\($0.absoluteString)\">" } ?? ""
		return """
		<!doctype html>
		<html>
		<head>
		  <meta charset="utf-8" />
		  <meta name="viewport" content="width=device-width, initial-scale=1" />
		  \(baseHref)
		  <style>
		    :root {
		      --bg: #0c0f14;
		      --surface: #0f141c;
		      --text: #e8edf6;
		      --muted: #a9b4c7;
		      --accent: #7bdcff;
		      --border: rgba(255,255,255,0.10);
		      --codeBg: rgba(255,255,255,0.06);
		    }
		    @media (prefers-color-scheme: light) {
		      :root {
		        --bg: #fbfbfa;
		        --surface: #ffffff;
		        --text: #111827;
		        --muted: #4b5563;
		        --accent: #0b6cff;
		        --border: rgba(17,24,39,0.12);
		        --codeBg: rgba(17,24,39,0.05);
		      }
		    }
		    html, body { height: 100%; }
		    body {
		      margin: 0;
		      background: radial-gradient(1200px 800px at 20% 0%, rgba(123,220,255,0.08), transparent 60%),
		                  radial-gradient(900px 600px at 90% 10%, rgba(11,108,255,0.08), transparent 55%),
		                  var(--bg);
		      color: var(--text);
		      font-family: ui-serif, "Iowan Old Style", "Georgia", serif;
		      -webkit-font-smoothing: antialiased;
		      text-rendering: optimizeLegibility;
		    }
		    .page {
		      max-width: 78ch;
		      padding: 42px 42px 72px;
		      margin: 0 auto;
		    }
		    h1,h2,h3,h4,h5,h6 {
		      font-family: ui-serif, "Iowan Old Style", "Georgia", serif;
		      letter-spacing: -0.01em;
		      line-height: 1.12;
		      margin: 1.2em 0 0.55em;
		    }
		    h1 { font-size: 2.2rem; }
		    h2 { font-size: 1.7rem; }
		    h3 { font-size: 1.35rem; }
		    p {
		      line-height: 1.7;
		      font-size: 1.05rem;
		      margin: 0.85em 0;
		    }
		    a { color: var(--accent); text-decoration: none; }
		    a:hover { text-decoration: underline; }
		    code {
		      font-family: ui-monospace, "SF Mono", Menlo, monospace;
		      font-size: 0.95em;
		      background: var(--codeBg);
		      padding: 0.12em 0.32em;
		      border-radius: 6px;
		    }
		    pre {
		      background: var(--surface);
		      border: 1px solid var(--border);
		      border-radius: 12px;
		      padding: 14px 16px;
		      overflow: auto;
		      margin: 1.1em 0;
		      box-shadow: 0 18px 50px rgba(0,0,0,0.18);
		    }
		    pre code { background: transparent; padding: 0; }
		    ul { padding-left: 1.25em; margin: 0.9em 0; }
		    li { line-height: 1.6; margin: 0.3em 0; }
		    img {
		      max-width: 100%;
		      border-radius: 14px;
		      border: 1px solid var(--border);
		      box-shadow: 0 18px 50px rgba(0,0,0,0.18);
		      margin: 1.2em 0;
		    }
		  </style>
		  <script>
		    window.__setBody = function(html) {
		      const main = document.querySelector('main.page');
		      if (!main) return;
		      main.innerHTML = html;
		    };
		    window.__scrollToProgress = function(p) {
		      p = Math.max(0, Math.min(1, p));
		      const doc = document.documentElement;
		      const maxY = Math.max(1, doc.scrollHeight - window.innerHeight);
		      window.scrollTo(0, maxY * p);
		    };
		  </script>
		</head>
		<body>
		  <main class="page">\(body)</main>
		</body>
		</html>
		"""
	}

	@MainActor
	final class Coordinator: NSObject, WKNavigationDelegate {
		private var lastBaseURL: URL?
		private var renderTask: Task<Void, Never>?

		func makeConfiguration() -> WKWebViewConfiguration {
			let config = WKWebViewConfiguration()
			config.preferences.javaScriptCanOpenWindowsAutomatically = false
			return config
		}

		func update(webView: WKWebView, controller: PreviewController, markdown: String, baseURL: URL?) {
			if lastBaseURL != baseURL {
				lastBaseURL = baseURL
				let html = PreviewWebView(controller: controller, markdown: markdown, baseURL: baseURL)
					.wrapHTML(body: MarkdownHTMLRenderer.render(markdown: markdown), baseURL: baseURL)
				webView.loadHTMLString(html, baseURL: baseURL)
				return
			}

			renderTask?.cancel()
			renderTask = Task { @MainActor in
				try? await Task.sleep(for: .milliseconds(220))
				if Task.isCancelled { return }
				controller.setBodyHTML(MarkdownHTMLRenderer.render(markdown: markdown))
			}
		}

		func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
			guard let url = navigationAction.request.url else {
				decisionHandler(.allow)
				return
			}

			if navigationAction.navigationType == .linkActivated {
				let scheme = url.scheme?.lowercased()
				if scheme == "http" || scheme == "https" || scheme == "mailto" {
					NSWorkspace.shared.open(url)
					decisionHandler(.cancel)
				} else {
					decisionHandler(.allow)
				}
				return
			}

			decisionHandler(.allow)
		}
	}
}
