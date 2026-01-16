import AppKit
import SwiftUI
import WebKit

@MainActor
private enum PreviewAssets {
	private static var cache: [String: String] = [:]

	static func js(named name: String) -> String {
		loadText(named: name, ext: "js")
			.replacingOccurrences(of: "</script", with: "<\\/script")
	}

	static func css(named name: String) -> String {
		loadText(named: name, ext: "css")
	}

	private static func loadText(named name: String, ext: String) -> String {
		let key = "\(name).\(ext)"
		if let cached = cache[key] { return cached }

		guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
			cache[key] = ""
			return ""
		}

		let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
		cache[key] = text
		return text
	}
}

@MainActor
final class PreviewController: ObservableObject {
	weak var webView: WKWebView?
	private var isReady: Bool = false
	private var pendingMarkdown: String? = nil
	private var pendingScrollProgress: Double? = nil
	private var pendingAnchorID: String? = nil

	func setMarkdown(_ markdown: String) {
		pendingMarkdown = markdown
		flushIfPossible()
	}

	func scrollTo(progress: Double) {
		pendingScrollProgress = min(max(progress, 0), 1)
		flushIfPossible()
	}

	func scrollToAnchor(_ id: String) {
		pendingAnchorID = id
		flushIfPossible()
	}

	func markReady() {
		isReady = true
		flushIfPossible()
	}

	private func flushIfPossible() {
		guard isReady, let webView else { return }

		if let markdown = pendingMarkdown {
			pendingMarkdown = nil
			if let json = try? String(data: JSONEncoder().encode(markdown), encoding: .utf8) {
				webView.evaluateJavaScript("window.__renderMarkdown(\(json));")
			}
		}

		if let progress = pendingScrollProgress {
			pendingScrollProgress = nil
			webView.evaluateJavaScript("window.__scrollToProgress(\(progress));")
		}

		if let id = pendingAnchorID {
			pendingAnchorID = nil
			if let json = try? String(data: JSONEncoder().encode(id), encoding: .utf8) {
				webView.evaluateJavaScript("window.__scrollToAnchor(\(json));")
			}
		}
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
		webView.loadHTMLString(wrapHTML(initialMarkdown: markdown, baseURL: baseURL), baseURL: baseURL)
		return webView
	}

	func updateNSView(_ nsView: WKWebView, context: Context) {
		context.coordinator.update(webView: nsView, controller: controller, markdown: markdown, baseURL: baseURL)
	}

	func makeCoordinator() -> Coordinator {
		Coordinator()
	}

	private func wrapHTML(initialMarkdown: String, baseURL: URL?) -> String {
		let baseHref = baseURL.map { "<base href=\"\($0.absoluteString)\">" } ?? ""
		let mdJSON = (try? String(data: JSONEncoder().encode(initialMarkdown), encoding: .utf8)) ?? "\"\""
		return """
		<!doctype html>
		<html lang="en">
		<head>
		  <meta charset="utf-8" />
		  <meta name="viewport" content="width=device-width, initial-scale=1" />
		  <meta name="color-scheme" content="light dark" />
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
		      scroll-margin-top: 24px;
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

		    blockquote {
		      margin: 1.1em 0;
		      padding: 0.2em 1em;
		      border-left: 3px solid var(--accent);
		      color: var(--muted);
		    }

		    table {
		      width: 100%;
		      border-collapse: collapse;
		      border: 1px solid var(--border);
		      border-radius: 12px;
		      overflow: hidden;
		      margin: 1.2em 0;
		      background: var(--surface);
		    }

		    th, td {
		      padding: 10px 12px;
		      border-bottom: 1px solid var(--border);
		      vertical-align: top;
		      line-height: 1.55;
		    }

		    th {
		      text-align: left;
		      font-weight: 650;
		      color: var(--text);
		      background: rgba(255,255,255,0.03);
		    }

		    tr:last-child td { border-bottom: none; }

		    hr {
		      border: 0;
		      height: 1px;
		      background: var(--border);
		      margin: 1.6em 0;
		    }

		    a:focus-visible,
		    button:focus-visible,
		    [tabindex]:focus-visible {
		      outline: 2px solid var(--accent);
		      outline-offset: 3px;
		      border-radius: 8px;
		    }

		    @media (prefers-reduced-motion: reduce) {
		      * { animation: none !important; transition: none !important; scroll-behavior: auto !important; }
		    }
		  </style>
		  <style>
		  \(PreviewAssets.css(named: "prism-theme.1.30.0.min"))
		  </style>
		  <script>\(PreviewAssets.js(named: "markdown-it.14.1.0.min"))</script>
		  <script>\(PreviewAssets.js(named: "markdown-it-anchor.9.2.0.min"))</script>
		  <script>\(PreviewAssets.js(named: "markdown-it-task-lists.2.1.1.min"))</script>
		  <script>\(PreviewAssets.js(named: "dompurify.3.3.1.min"))</script>
		  <script>\(PreviewAssets.js(named: "prism-core.1.30.0.min"))</script>
		  <script>\(PreviewAssets.js(named: "prism-clike.1.30.0.min"))</script>
		  <script>\(PreviewAssets.js(named: "prism-javascript.1.30.0.min"))</script>
		  <script>\(PreviewAssets.js(named: "prism-typescript.1.30.0.min"))</script>
		  <script>\(PreviewAssets.js(named: "prism-json.1.30.0.min"))</script>
		  <script>\(PreviewAssets.js(named: "prism-bash.1.30.0.min"))</script>
		  <script>\(PreviewAssets.js(named: "prism-python.1.30.0.min"))</script>
		  <script>\(PreviewAssets.js(named: "prism-swift.1.30.0.min"))</script>
		  <script>
		    window.__scrollToProgress = function(p) {
		      p = Math.max(0, Math.min(1, p));
		      const doc = document.documentElement;
		      const maxY = Math.max(1, doc.scrollHeight - window.innerHeight);
		      window.scrollTo(0, maxY * p);
		    };

		    window.__scrollToAnchor = function(id) {
		      const el = document.getElementById(id);
		      if (el && el.scrollIntoView) el.scrollIntoView({ block: "start" });
		    };

		    window.__setup = function() {
		      if (window.__md) return;
		      const md = window.markdownit({ html: true, linkify: true, typographer: true });
		      if (window.markdownItAnchor) md.use(window.markdownItAnchor, { permalink: false, tabIndex: "-1" });
		      if (window.markdownitTaskLists) md.use(window.markdownitTaskLists, { enabled: true, label: true, labelAfter: true });
		      window.__md = md;
		    };

		    window.__renderMarkdown = function(markdown) {
		      window.__setup();
		      const main = document.querySelector('main.page');
		      if (!main) return;

		      const raw = window.__md ? window.__md.render(markdown || "") : "";
		      const uri = /^(?:(?:https?|mailto|tel|file):|[^a-z]|[a-z+\\.\\-]+(?:[^a-z+\\.\\-:]|$))/i;
		      const clean = window.DOMPurify
		        ? window.DOMPurify.sanitize(raw, {
		            USE_PROFILES: { html: true },
		            ADD_DATA_URI_TAGS: ["img"],
		            ALLOWED_URI_REGEXP: uri,
		          })
		        : raw;

		      main.innerHTML = clean;
		      if (window.Prism && window.Prism.highlightAllUnder) {
		        window.Prism.highlightAllUnder(main);
		      }
		    };

		    window.addEventListener("DOMContentLoaded", function() {
		      window.__renderMarkdown(\(mdJSON));
		    });
		  </script>
		</head>
		<body>
		  <main class="page"></main>
		</body>
		</html>
		"""
	}

	@MainActor
	final class Coordinator: NSObject, WKNavigationDelegate {
		private var lastBaseURL: URL?
		private var renderTask: Task<Void, Never>?
		private weak var controller: PreviewController?

		func makeConfiguration() -> WKWebViewConfiguration {
			let config = WKWebViewConfiguration()
			config.preferences.javaScriptCanOpenWindowsAutomatically = false
			return config
		}

		func update(webView: WKWebView, controller: PreviewController, markdown: String, baseURL: URL?) {
			self.controller = controller
			if lastBaseURL != baseURL {
				lastBaseURL = baseURL
				let html = PreviewWebView(controller: controller, markdown: markdown, baseURL: baseURL)
					.wrapHTML(initialMarkdown: markdown, baseURL: baseURL)
				webView.loadHTMLString(html, baseURL: baseURL)
				return
			}

			renderTask?.cancel()
			renderTask = Task { @MainActor in
				try? await Task.sleep(for: .milliseconds(220))
				if Task.isCancelled { return }
				controller.setMarkdown(markdown)
			}
		}

		func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
			controller?.markReady()
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
