import Foundation

enum MarkdownRenderer {
    static func prepareMarkdownForPreview(_ text: String, baseURL: URL?) -> String {
        let nsText = text as NSString
        let pattern = #"!\[([^\]]*)\]\(([^)\s]+)(?:\s+"([^"]*)")?\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard matches.isEmpty == false else {
            return text
        }

        var markdown = text

        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }

            let altText = nsText.substring(with: match.range(at: 1))
            let destination = nsText.substring(with: match.range(at: 2))
            let title = match.range(at: 3).location != NSNotFound ? nsText.substring(with: match.range(at: 3)) : nil
            let previewDestination = previewImageDestination(destination, baseURL: baseURL)
            let titleSuffix = title.map { " \"\($0)\"" } ?? ""
            let replacement = "![\(altText)](\(previewDestination)\(titleSuffix))"

            guard let range = Range(match.range, in: markdown) else { continue }
            markdown.replaceSubrange(range, with: replacement)
        }

        return markdown
    }

    static func htmlDocument() -> String {
        let markdownItScript = bundledMarkdownItScript()
        let githubStylesheet = bundledGitHubStylesheet()
        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <script>\(markdownItScript)</script>
          <style>
            :root {
              color-scheme: light dark;
              --base-font-size: 16px;
              --text-color: rgba(28, 28, 30, 0.96);
              --secondary-text-color: rgba(60, 60, 67, 0.78);
              --rule-color: rgba(60, 60, 67, 0.18);
              --code-background: rgba(120, 120, 128, 0.12);
              --inline-code-background: rgba(120, 120, 128, 0.12);
              --block-code-background: rgba(120, 120, 128, 0.12);
              --blockquote-accent: rgba(10, 132, 255, 0.56);
              --table-header: rgba(120, 120, 128, 0.08);
              --link-color: #0A84FF;
              --panel-background: rgba(255, 255, 255, 0.88);
              --panel-border: rgba(60, 60, 67, 0.16);
              --content-padding-x: 24px;
              --content-padding-y: 24px;
            }

            body.theme-light {
              color-scheme: light;
            }

            body.theme-dark {
              color-scheme: dark;
              --text-color: rgba(255, 255, 255, 0.92);
              --secondary-text-color: rgba(235, 235, 245, 0.72);
              --rule-color: rgba(84, 84, 88, 0.65);
              --code-background: rgba(255, 255, 255, 0.10);
              --inline-code-background: rgba(255, 255, 255, 0.10);
              --block-code-background: rgba(255, 255, 255, 0.08);
              --blockquote-accent: rgba(100, 210, 255, 0.68);
              --table-header: rgba(255, 255, 255, 0.06);
              --link-color: #64D2FF;
              --panel-background: rgba(28, 28, 30, 0.72);
              --panel-border: rgba(255, 255, 255, 0.12);
            }

            @media (prefers-color-scheme: dark) {
              body:not(.theme-light):not(.theme-dark) {
                color-scheme: dark;
                --text-color: rgba(255, 255, 255, 0.92);
                --secondary-text-color: rgba(235, 235, 245, 0.72);
                --rule-color: rgba(84, 84, 88, 0.65);
                --code-background: rgba(255, 255, 255, 0.10);
                --inline-code-background: rgba(255, 255, 255, 0.10);
                --block-code-background: rgba(255, 255, 255, 0.08);
                --blockquote-accent: rgba(100, 210, 255, 0.68);
                --table-header: rgba(255, 255, 255, 0.06);
                --link-color: #64D2FF;
                --panel-background: rgba(28, 28, 30, 0.72);
                --panel-border: rgba(255, 255, 255, 0.12);
              }
            }

            \(githubStylesheet)

            * {
              box-sizing: border-box;
            }

            html, body {
              margin: 0;
              padding: 0;
              background: transparent;
            }

            body {
              color: var(--text-color);
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
              font-size: var(--base-font-size);
              line-height: 1.6;
              -webkit-font-smoothing: antialiased;
              text-rendering: optimizeLegibility;
            }

            body.overlay {
              --content-padding-x: 16px;
              --content-padding-y: 18px;
            }

            #content {
              padding: var(--content-padding-y) var(--content-padding-x);
            }

            #content.md-github__body {
              width: min(100%, 920px);
              max-width: 920px;
              margin: 0 auto;
              padding: clamp(20px, 3vw, 32px);
              font-size: var(--base-font-size);
              line-height: 1.6;
              color: var(--text-color);
              background: transparent !important;
              border: 0 !important;
              border-radius: 0 !important;
              box-shadow: none !important;
            }

            body.overlay #content.md-github__body {
              width: 100%;
              max-width: none;
              padding: var(--content-padding-y) var(--content-padding-x);
              background: transparent !important;
              border: 0 !important;
              border-radius: 0 !important;
              box-shadow: none !important;
            }

            h1, h2, h3, h4, h5, h6 {
              margin: 0 0 0.55em;
              line-height: 1.16;
              font-weight: 760;
              letter-spacing: -0.03em;
            }

            h1 {
              font-size: 2em;
            }

            h2 {
              font-size: 1.55em;
            }

            h3 {
              font-size: 1.25em;
            }

            h4, h5, h6 {
              font-size: 1.05em;
            }

            p, ul, ol, blockquote, pre, table, dl {
              margin: 0 0 1.1em;
            }

            p, li, blockquote {
              white-space: pre-wrap;
              overflow-wrap: anywhere;
            }

            ul, ol {
              margin-left: 1.15em;
              padding-left: 0.45em;
            }

            ul ul, ul ol, ol ul, ol ol {
              margin-top: 0.35em;
              margin-bottom: 0.35em;
            }

            li {
              margin: 0.18em 0;
            }

            li > p {
              margin: 0.16em 0;
            }

            li > ul, li > ol {
              margin-left: 0.9em;
            }

            ul {
              list-style-type: disc;
            }

            ul ul {
              list-style-type: circle;
            }

            ul ul ul {
              list-style-type: square;
            }

            li::marker {
              color: var(--secondary-text-color);
            }

            ol li::marker {
              font-variant-numeric: tabular-nums;
            }

            ul.task-list {
              list-style: none;
              padding-left: 0;
              margin-left: 0;
            }

            ul.task-list li {
              display: flex;
              gap: 0.55em;
              align-items: flex-start;
              margin: 0.3em 0;
            }

            .task-marker {
              color: var(--secondary-text-color);
              font-size: 0.95em;
              min-width: 1.5em;
            }

            blockquote {
              padding: 0.1em 0 0.1em 1em;
              border-left: 3px solid var(--blockquote-accent);
              color: var(--secondary-text-color);
            }

            blockquote p:last-child {
              margin-bottom: 0;
            }

            dl {
              margin-left: 0;
            }

            dt {
              font-weight: 670;
              margin-top: 0.8em;
            }

            dd {
              margin: 0.18em 0 0.65em 1.3em;
            }

            pre {
              padding: 14px 16px;
              border-radius: 12px;
              background: var(--code-background);
              overflow-x: auto;
            }

            pre code {
              display: block;
              white-space: pre;
              background: transparent;
              padding: 0;
              border-radius: 0;
              font-size: 0.94em;
            }

            code {
              font-family: "SF Mono", "SFMono-Regular", Menlo, Monaco, Consolas, monospace;
              font-size: 0.92em;
              padding: 0.12em 0.36em;
              border-radius: 6px;
              background: var(--code-background);
            }

            .code-language {
              display: inline-block;
              margin-bottom: 0.55em;
              color: var(--secondary-text-color);
              font-size: 0.72em;
              font-weight: 700;
              letter-spacing: 0.08em;
              text-transform: uppercase;
            }

            table {
              width: 100%;
              border-collapse: collapse;
              display: block;
              overflow-x: auto;
            }

            thead th {
              background: var(--table-header);
            }

            th, td {
              padding: 10px 12px;
              border-bottom: 1px solid var(--rule-color);
              vertical-align: top;
              text-align: left;
              min-width: 7em;
            }

            tr:last-child td {
              border-bottom: 0;
            }

            hr {
              border: 0;
              border-top: 1px solid var(--rule-color);
              margin: 1.35em 0;
            }

            a {
              color: var(--link-color);
              text-decoration: none;
            }

            a:hover {
              text-decoration: underline;
            }

            img {
              display: block;
              max-width: 100%;
              height: auto;
              border-radius: 10px;
            }

            mark {
              background: color-mix(in srgb, var(--link-color) 18%, transparent);
              color: inherit;
              border-radius: 4px;
              padding: 0.02em 0.18em;
            }

            ins {
              text-decoration-thickness: 0.12em;
              text-decoration-color: color-mix(in srgb, var(--link-color) 55%, transparent);
              text-underline-offset: 0.12em;
            }

            .footnotes {
              color: var(--secondary-text-color);
              font-size: 0.94em;
            }

            .footnotes-list {
              margin-bottom: 0;
            }

            .footnote-ref {
              font-size: 0.76em;
              vertical-align: super;
            }

            .footnote-backref {
              text-decoration: none;
            }

            #content.md-github__body h1,
            #content.md-github__body h2 {
              border-bottom-color: var(--rule-color);
            }

            #content.md-github__body h6,
            #content.md-github__body blockquote,
            #content.md-github__body .footnotes {
              color: var(--secondary-text-color);
            }

            #content.md-github__body p,
            #content.md-github__body li,
            #content.md-github__body blockquote {
              white-space: normal;
              overflow-wrap: anywhere;
              word-break: normal;
            }

            #content.md-github__body a {
              color: var(--link-color);
            }

            #content.md-github__body blockquote {
              border-left-color: var(--blockquote-accent);
            }

            #content.md-github__body code,
            #content.md-github__body tt {
              background: var(--inline-code-background);
            }

            #content.md-github__body pre {
              background: var(--block-code-background);
              border-radius: 10px;
            }

            #content.md-github__body hr {
              background-color: var(--rule-color);
            }

            #content.md-github__body table tr {
              background-color: transparent;
              border-top-color: var(--rule-color);
            }

            #content.md-github__body table th {
              background: var(--table-header);
            }

            #content.md-github__body table td,
            #content.md-github__body table th {
              border-color: var(--rule-color);
            }

            #content.md-github__body img {
              display: block;
              max-width: 100%;
              height: auto;
              border-radius: 10px;
            }

            #content.md-github__body .contains-task-list {
              padding-left: 0;
            }

            #content.md-github__body .task-list-item,
            #content.md-github__body .md-github__task-item {
              list-style-type: none;
            }

            #content.md-github__body .task-list-item + .task-list-item,
            #content.md-github__body .md-github__task-item + .md-github__task-item {
              margin-top: 3px;
            }

            #content.md-github__body .task-list-item-checkbox,
            #content.md-github__body .md-github__task-checkbox {
              font: inherit;
              overflow: visible;
              font-family: inherit;
              font-size: inherit;
              line-height: inherit;
              box-sizing: border-box;
              padding: 0;
              margin: 0 0.2em 0.25em -1.6em;
              vertical-align: middle;
            }

            #content.md-github__body .code-language {
              display: inline-block;
              margin: 0 0 0.55em;
              color: var(--secondary-text-color);
              font-size: 0.72em;
              font-weight: 700;
              letter-spacing: 0.08em;
              text-transform: uppercase;
            }

            #content.md-github__body dl {
              margin-top: 0;
              margin-bottom: 16px;
            }

            #content.md-github__body dt {
              font-weight: 600;
              margin-top: 16px;
            }

            #content.md-github__body dd {
              margin: 0 0 16px 1.4em;
            }

            #content.md-github__body mark {
              background: color-mix(in srgb, var(--link-color) 18%, transparent);
              color: inherit;
            }

            #content.md-github__body ins {
              text-decoration-color: color-mix(in srgb, var(--link-color) 55%, transparent);
            }
          </style>
          <script>
            window.__overlayNotesApplyGitHubTheme = function(content) {
              if (!content) {
                return;
              }

              content.classList.add("md-github__body");

              [
                "h1",
                "h2",
                "h3",
                "h4",
                "h5",
                "h6",
                "hr",
                "p",
                "b",
                "strong",
                "blockquote",
                "a",
                "pre",
                "code",
                "tt",
                "ol",
                "ul",
                "li",
                "table"
              ].forEach(function(tag) {
                content.querySelectorAll(tag).forEach(function(node) {
                  node.classList.add("md-github__" + tag);
                });
              });

              content.querySelectorAll(".task-list-item").forEach(function(node) {
                node.classList.add("md-github__task-item");
              });

              content.querySelectorAll(".task-list-item-checkbox").forEach(function(node) {
                node.classList.add("md-github__task-checkbox");
              });
            };

            window.__overlayNotesSourceAttrs = function(token) {
              if (!token || !token.map || token.map.length < 2) {
                return "";
              }

              return " data-source-line-start=\\"" + String(token.map[0] + 1) + "\\" data-source-line-end=\\"" + String(token.map[1] + 1) + "\\"";
            };

            window.__overlayNotesViewportAnchorOffset = function() {
              const doc = document.documentElement;
              const body = document.body;
              const viewportHeight = window.innerHeight || doc.clientHeight || body.clientHeight || 0;
              return Math.max(24, viewportHeight * 0.24);
            };

            window.__overlayNotesRebuildSourceAnchors = function() {
              const content = document.getElementById("content");
              const doc = document.documentElement;
              const body = document.body;
              const scrollTop = window.scrollY || doc.scrollTop || body.scrollTop || 0;

              if (!content) {
                window.__overlayNotesSourceAnchors = [];
                return;
              }

              window.__overlayNotesSourceAnchors = Array.from(content.querySelectorAll("[data-source-line-start]")).map(function(node) {
                const rect = node.getBoundingClientRect();
                const start = parseInt(node.getAttribute("data-source-line-start") || "1", 10);
                const end = parseInt(node.getAttribute("data-source-line-end") || String(start), 10);
                return {
                  start: start,
                  end: Math.max(start, end),
                  top: rect.top + scrollTop,
                  height: Math.max(rect.height, 1)
                };
              }).sort(function(left, right) {
                if (left.top === right.top) {
                  return left.start - right.start;
                }

                return left.top - right.top;
              });
            };

            window.__overlayNotesSourceLineForOffset = function(offset) {
              const anchors = window.__overlayNotesSourceAnchors || [];
              if (!anchors.length) {
                return null;
              }

              const containingAnchors = anchors.filter(function(anchor) {
                return offset >= anchor.top && offset < anchor.top + anchor.height;
              });

              if (containingAnchors.length) {
                containingAnchors.sort(function(left, right) {
                  if (left.height === right.height) {
                    return (left.end - left.start) - (right.end - right.start);
                  }

                  return left.height - right.height;
                });
              }

              let low = 0;
              let high = anchors.length - 1;
              let candidate = containingAnchors[0] || anchors[0];

              if (!containingAnchors.length) {
                while (low <= high) {
                  const middle = Math.floor((low + high) / 2);
                  if (anchors[middle].top <= offset + 2) {
                    candidate = anchors[middle];
                    low = middle + 1;
                  } else {
                    high = middle - 1;
                  }
                }
              }

              const span = Math.max(1, candidate.end - candidate.start);
              if (candidate.height <= 1 || span <= 1) {
                return candidate.start;
              }

              const relativeOffset = Math.min(Math.max(offset - candidate.top, 0), candidate.height);
              const interpolatedLine = candidate.start + Math.floor((relativeOffset / candidate.height) * span);
              return Math.max(candidate.start, Math.min(interpolatedLine, candidate.end - 1));
            };

            window.__overlayNotesOffsetForSourceLine = function(sourceLine) {
              const anchors = window.__overlayNotesSourceAnchors || [];
              if (!anchors.length || sourceLine == null) {
                return null;
              }

              const containingAnchors = anchors.filter(function(anchor) {
                return anchor.start <= sourceLine && sourceLine < anchor.end;
              });

              let candidate = null;
              if (containingAnchors.length) {
                containingAnchors.sort(function(left, right) {
                  if (left.start !== right.start) {
                    return right.start - left.start;
                  }

                  const leftSpan = left.end - left.start;
                  const rightSpan = right.end - right.start;
                  if (leftSpan !== rightSpan) {
                    return leftSpan - rightSpan;
                  }

                  return left.top - right.top;
                });
                candidate = containingAnchors[0];
              } else {
                for (let index = 0; index < anchors.length; index += 1) {
                  if (anchors[index].start <= sourceLine) {
                    candidate = anchors[index];
                  } else {
                    break;
                  }
                }
              }

              if (!candidate) {
                candidate = anchors[0];
              }

              const span = Math.max(1, candidate.end - candidate.start);
              if (candidate.height <= 1 || span <= 1) {
                return candidate.top;
              }

              const relativeLine = Math.min(Math.max(sourceLine - candidate.start, 0), span - 1);
              return candidate.top + (candidate.height * (relativeLine / span));
            };

            window.__overlayNotesResolveEdgeAffinity = function(offset, maxOffset, viewportHeight) {
              if (maxOffset <= 0) {
                return "top";
              }

              const remainingOffset = Math.max(0, maxOffset - offset);
              const edgeThreshold = Math.min(Math.max(88, viewportHeight * 0.16), maxOffset * 0.5);

              if (offset <= edgeThreshold) {
                return "top";
              }

              if (remainingOffset <= edgeThreshold) {
                return "bottom";
              }

              return "middle";
            };

            window.__overlayNotesGetScrollProgress = function() {
              const doc = document.documentElement;
              const body = document.body;
              const scrollTop = window.scrollY || doc.scrollTop || body.scrollTop || 0;
              const scrollHeight = Math.max(doc.scrollHeight, body.scrollHeight, 0);
              const viewportHeight = window.innerHeight || doc.clientHeight || body.clientHeight || 0;
              const maxOffset = Math.max(0, scrollHeight - viewportHeight);

              if (maxOffset <= 0) {
                return 0;
              }

              return Math.min(Math.max(scrollTop / maxOffset, 0), 1);
            };

            window.__overlayNotesGetScrollState = function() {
              const doc = document.documentElement;
              const body = document.body;
              const scrollTop = window.scrollY || doc.scrollTop || body.scrollTop || 0;
              const scrollHeight = Math.max(doc.scrollHeight, body.scrollHeight, 0);
              const viewportHeight = window.innerHeight || doc.clientHeight || body.clientHeight || 0;
              const maxOffset = Math.max(0, scrollHeight - viewportHeight);

              return {
                progress: window.__overlayNotesGetScrollProgress(),
                edgeAffinity: window.__overlayNotesResolveEdgeAffinity(scrollTop, maxOffset, viewportHeight),
                sourceLine: window.__overlayNotesSourceLineForOffset(scrollTop + window.__overlayNotesViewportAnchorOffset())
              };
            };

            window.__overlayNotesPostScrollProgress = function() {
              if (window.__overlayNotesIgnoreScrollEvents) {
                return;
              }

              const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.overlayNotesScroll;
              if (!handler) {
                return;
              }

              handler.postMessage(window.__overlayNotesGetScrollState());
            };

            window.__overlayNotesPostUserScrollIntent = function() {
              const now = Date.now();
              if (window.__overlayNotesLastUserScrollIntent && now - window.__overlayNotesLastUserScrollIntent < 80) {
                return;
              }

              window.__overlayNotesLastUserScrollIntent = now;
              const handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.overlayNotesUserScroll;
              if (handler) {
                handler.postMessage("user");
              }
            };

            window.__overlayNotesSetScrollProgress = function(progress, edgeAffinity, sourceLine) {
              const clampedProgress = Math.min(Math.max(progress || 0, 0), 1);
              const doc = document.documentElement;
              const body = document.body;
              const scrollHeight = Math.max(doc.scrollHeight, body.scrollHeight, 0);
              const viewportHeight = window.innerHeight || doc.clientHeight || body.clientHeight || 0;
              const maxOffset = Math.max(0, scrollHeight - viewportHeight);
              const progressOffset = maxOffset * clampedProgress;
              let offset = progressOffset;

              const sourceAnchoredOffset = window.__overlayNotesOffsetForSourceLine(sourceLine);
              if (sourceAnchoredOffset != null) {
                const viewportAnchorOffset = window.__overlayNotesViewportAnchorOffset();
                const alignedOffset = sourceAnchoredOffset - viewportAnchorOffset;
                offset = edgeAffinity === "middle"
                  ? (alignedOffset * 0.88) + (progressOffset * 0.12)
                  : alignedOffset;
              }

              if (edgeAffinity === "top") {
                offset = 0;
              } else if (edgeAffinity === "bottom") {
                offset = maxOffset;
              }

              offset = Math.min(Math.max(offset, 0), maxOffset);

              window.__overlayNotesIgnoreScrollEvents = true;
              const scrollingElement = document.scrollingElement || doc || body;
              if (scrollingElement) {
                scrollingElement.scrollTop = offset;
              } else {
                window.scrollTo(0, offset);
              }

              window.requestAnimationFrame(function() {
                window.requestAnimationFrame(function() {
                  window.__overlayNotesIgnoreScrollEvents = false;
                });
              });

              return clampedProgress;
            };

            window.addEventListener("scroll", function() {
              if (window.__overlayNotesScrollTicking) {
                return;
              }

              window.__overlayNotesScrollTicking = true;
              window.requestAnimationFrame(function() {
                window.__overlayNotesScrollTicking = false;
                window.__overlayNotesPostScrollProgress();
              });
            }, { passive: true });

            window.addEventListener("wheel", function() {
              window.__overlayNotesPostUserScrollIntent();
            }, { passive: true });

            window.addEventListener("keydown", function(event) {
              if (["ArrowUp", "ArrowDown", "PageUp", "PageDown", "Home", "End", " "].includes(event.key)) {
                window.__overlayNotesPostUserScrollIntent();
              }
            });

            window.addEventListener("resize", function() {
              window.__overlayNotesRebuildSourceAnchors();
              window.__overlayNotesPostScrollProgress();
            });

            window.__overlayNotesParser = function() {
              if (!window.markdownit) {
                return null;
              }

              const md = window.markdownit({
                html: false,
                linkify: true,
                typographer: true,
                breaks: false
              });

              [
                window.markdownitAbbr,
                window.markdownitDeflist,
                window.markdownitFootnote,
                window.markdownitIns,
                window.markdownitMark,
                window.markdownitTaskLists,
                window.markdownitSub,
                window.markdownitSup,
                window.markdownitEmoji
              ].filter(Boolean).forEach(function(plugin) {
                md.use(plugin);
              });

              const defaultFenceRenderer = md.renderer.rules.fence;
              md.renderer.rules.fence = function(tokens, idx, options, env, self) {
                const html = defaultFenceRenderer ? defaultFenceRenderer(tokens, idx, options, env, self) : self.renderToken(tokens, idx, options);
                const attrs = window.__overlayNotesSourceAttrs(tokens[idx]);
                return attrs ? html.replace(/^<pre\\b/, "<pre" + attrs) : html;
              };

              const defaultCodeBlockRenderer = md.renderer.rules.code_block;
              md.renderer.rules.code_block = function(tokens, idx, options, env, self) {
                const html = defaultCodeBlockRenderer ? defaultCodeBlockRenderer(tokens, idx, options, env, self) : self.renderToken(tokens, idx, options);
                const attrs = window.__overlayNotesSourceAttrs(tokens[idx]);
                return attrs ? html.replace(/^<pre\\b/, "<pre" + attrs) : html;
              };

              return md;
            };

            window.__overlayNotesUpdate = function(payload) {
              const body = document.body;
              body.classList.toggle("overlay", payload.isOverlay);
              body.classList.toggle("theme-light", payload.themeOverride === "light");
              body.classList.toggle("theme-dark", payload.themeOverride === "dark");
              document.documentElement.style.setProperty("--base-font-size", payload.baseFontSize + "px");
              const content = document.getElementById("content");
              const preservedState = window.__overlayNotesGetScrollState();

              try {
                const parser = window.__overlayNotesParser();
                if (parser) {
                  const env = {};
                  const tokens = parser.parse(payload.markdown, env);
                  tokens.forEach(function(token) {
                    if (!token || !token.map || !token.block) {
                      return;
                    }

                    const isOpenBlock = token.nesting === 1 && /_open$/.test(token.type);
                    const isSelfClosingBlock = token.nesting === 0 && token.type !== "inline" && !!token.tag;
                    if (!isOpenBlock && !isSelfClosingBlock) {
                      return;
                    }

                    token.attrSet("data-source-line-start", String(token.map[0] + 1));
                    token.attrSet("data-source-line-end", String(token.map[1] + 1));
                  });
                  content.innerHTML = parser.renderer.render(tokens, parser.options, env);
                  window.__overlayNotesApplyGitHubTheme(content);
                } else {
                  content.innerHTML = payload.fallbackHTML;
                  window.__overlayNotesApplyGitHubTheme(content);
                }
              } catch (error) {
                console.error("markdown-it render failed", error);
                content.innerHTML = payload.fallbackHTML;
                window.__overlayNotesApplyGitHubTheme(content);
              }

              window.__overlayNotesRebuildSourceAnchors();
              content.querySelectorAll("img").forEach(function(image) {
                if (image.complete) {
                  return;
                }

                image.addEventListener("load", function() {
                  window.__overlayNotesRebuildSourceAnchors();
                  window.__overlayNotesPostScrollProgress();
                }, { once: true });
              });
              window.__overlayNotesSetScrollProgress(
                preservedState.progress,
                preservedState.edgeAffinity,
                preservedState.sourceLine
              );
              window.__overlayNotesPostScrollProgress();
            };
          </script>
        </head>
        <body>
          <main id="content"></main>
        </body>
        </html>
        """
    }

    static func renderHTMLBody(_ text: String, baseURL: URL?) -> String {
        let source = text.isEmpty ? "Start typing your Markdown note to preview it here." : text
        return MarkdownBlockParser.parse(source)
            .map { render($0, baseURL: baseURL) }
            .joined(separator: "\n")
    }

    static func baseFontSize(textScale: Double, isOverlay: Bool) -> Double {
        let base = isOverlay ? 18.0 : 16.0
        let minimum = isOverlay ? 14.0 : 13.0
        return max(minimum, base * textScale)
    }

    private static func render(_ block: MarkdownBlock, baseURL: URL?) -> String {
        switch block {
        case let .heading(level, text):
            return "<h\(level)>\(inlineHTML(text, baseURL: baseURL))</h\(level)>"
        case let .paragraph(text):
            return "<p>\(inlineHTML(text, baseURL: baseURL))</p>"
        case let .unorderedList(items):
            let isTaskList = items.allSatisfy { if case .task = $0.kind { return true } else { return false } }
            let className = isTaskList ? " class=\"task-list\"" : ""
            let body = items.map { renderUnorderedListItem($0, baseURL: baseURL) }.joined()
            return "<ul\(className)>\(body)</ul>"
        case let .orderedList(items):
            let body = items.map { item in
                "<li value=\"\(attributeEscaped(item.number))\">\(inlineHTML(item.text, baseURL: baseURL))</li>"
            }.joined()
            return "<ol>\(body)</ol>"
        case let .blockQuote(paragraphs):
            let body = paragraphs
                .map { "<p>\(inlineHTML($0, baseURL: baseURL))</p>" }
                .joined()
            return "<blockquote>\(body)</blockquote>"
        case let .codeBlock(language, code):
            let languageHTML: String
            if let language, language.isEmpty == false {
                languageHTML = "<div class=\"code-language\">\(htmlEscaped(language))</div>"
            } else {
                languageHTML = ""
            }
            return "\(languageHTML)<pre><code>\(htmlEscaped(code))</code></pre>"
        case let .table(header, alignments, rows):
            let head = header.enumerated().map { index, cell in
                "<th\(alignmentStyle(alignments[safe: index]))>\(inlineHTML(cell, baseURL: baseURL))</th>"
            }.joined()

            let body = rows.map { row in
                let cells = row.enumerated().map { index, cell in
                    "<td\(alignmentStyle(alignments[safe: index]))>\(inlineHTML(cell, baseURL: baseURL))</td>"
                }.joined()
                return "<tr>\(cells)</tr>"
            }.joined()

            return "<table><thead><tr>\(head)</tr></thead><tbody>\(body)</tbody></table>"
        case .thematicBreak:
            return "<hr>"
        }
    }

    private static func renderUnorderedListItem(_ item: MarkdownListItem, baseURL: URL?) -> String {
        switch item.kind {
        case .plain:
            return "<li>\(inlineHTML(item.text, baseURL: baseURL))</li>"
        case let .task(isChecked):
            let marker = isChecked ? "&#x2611;" : "&#x2610;"
            return "<li><span class=\"task-marker\">\(marker)</span><span>\(inlineHTML(item.text, baseURL: baseURL))</span></li>"
        }
    }

    private static func inlineHTML(_ text: String, baseURL: URL?) -> String {
        let preprocessed = preprocessInlineMarkdown(text, baseURL: baseURL)
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        let parsed = (try? NSAttributedString(markdown: preprocessed.markdown, options: options, baseURL: nil))
            ?? NSAttributedString(string: preprocessed.markdown)

        var html = ""
        parsed.enumerateAttributes(in: NSRange(location: 0, length: parsed.length)) { attributes, range, _ in
            let fragment = parsed.attributedSubstring(from: range).string
            var segment = htmlEscaped(fragment)

            if let rawValue = (attributes[.inlinePresentationIntent] as? NSNumber)?.intValue {
                segment = wrappedInlineHTML(segment, rawValue: rawValue)
            }

            if let linkValue = attributes[.link] {
                let href = attributeEscaped(String(describing: linkValue))
                segment = "<a href=\"\(href)\">\(segment)</a>"
            }

            html += segment
        }

        for replacement in preprocessed.replacements {
            html = html.replacingOccurrences(of: htmlEscaped(replacement.token), with: replacement.html)
        }

        return html
    }

    private static func preprocessInlineMarkdown(_ text: String, baseURL: URL?) -> (markdown: String, replacements: [(token: String, html: String)]) {
        let nsText = text as NSString
        let pattern = #"!\[([^\]]*)\]\(([^)\s]+)(?:\s+"([^"]*)")?\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (text, [])
        }

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard matches.isEmpty == false else {
            return (text, [])
        }

        var markdown = text
        var replacements: [(token: String, html: String)] = []

        for (index, match) in matches.enumerated().reversed() {
            guard match.numberOfRanges >= 3 else { continue }

            let altText = nsText.substring(with: match.range(at: 1))
            let destination = nsText.substring(with: match.range(at: 2))
            let title = match.range(at: 3).location != NSNotFound ? nsText.substring(with: match.range(at: 3)) : nil
            let token = "@@OVERLAY_NOTES_IMAGE_\(index)@@"
            let imageHTML = imageHTML(altText: altText, destination: destination, title: title, baseURL: baseURL)

            guard let range = Range(match.range, in: markdown) else { continue }
            markdown.replaceSubrange(range, with: token)
            replacements.append((token: token, html: imageHTML))
        }

        return (markdown, replacements)
    }

    private static func wrappedInlineHTML(_ html: String, rawValue: Int) -> String {
        var output = html

        if rawValue & 4 != 0 {
            output = "<code>\(output)</code>"
        }

        if rawValue & 32 != 0 {
            output = "<del>\(output)</del>"
        }

        if rawValue & 1 != 0 {
            output = "<em>\(output)</em>"
        }

        if rawValue & 2 != 0 {
            output = "<strong>\(output)</strong>"
        }

        return output
    }

    private static func alignmentStyle(_ alignment: MarkdownTableAlignment?) -> String {
        guard let alignment else { return "" }
        switch alignment {
        case .left:
            return " style=\"text-align: left;\""
        case .center:
            return " style=\"text-align: center;\""
        case .right:
            return " style=\"text-align: right;\""
        }
    }

    private static func htmlEscaped(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func attributeEscaped(_ text: String) -> String {
        htmlEscaped(text)
    }

    private static func bundledMarkdownItScript() -> String {
        [
            resourceText(named: "markdown-it.min", fileExtension: "js"),
            resourceText(named: "markdown-it-task-lists.min", fileExtension: "js")
        ]
        .compactMap { $0 }
        .map { $0.replacingOccurrences(of: "</script", with: "<\\/script") }
        .joined(separator: "\n")
    }

    private static func bundledGitHubStylesheet() -> String {
        resourceText(named: "github", fileExtension: "css") ?? ""
    }

    private static func resourceText(named name: String, fileExtension: String) -> String? {
        for candidate in resourceURLs(named: name, fileExtension: fileExtension) {
            if let contents = try? String(contentsOf: candidate, encoding: .utf8) {
                return contents
            }
        }

        return nil
    }

    private static func resourceURLs(named name: String, fileExtension: String) -> [URL] {
        [
            resourceBundle.url(forResource: name, withExtension: fileExtension),
            resourceBundle.url(forResource: name, withExtension: fileExtension, subdirectory: "Vendor"),
            resourceBundle.url(forResource: name, withExtension: fileExtension, subdirectory: "Resources/Vendor")
        ]
        .compactMap { $0 }
    }

    private static func imageHTML(altText: String, destination: String, title: String?, baseURL: URL?) -> String {
        let resolvedDestination = resolvedResourceDestination(destination, baseURL: baseURL)
        let titleAttribute: String
        if let title, title.isEmpty == false {
            titleAttribute = " title=\"\(attributeEscaped(title))\""
        } else {
            titleAttribute = ""
        }

        return "<img src=\"\(attributeEscaped(resolvedDestination))\" alt=\"\(attributeEscaped(altText))\"\(titleAttribute)>"
    }

    private static func resolvedResourceDestination(_ destination: String, baseURL: URL?) -> String {
        guard let baseURL else {
            return destination
        }

        if let absoluteURL = URL(string: destination), absoluteURL.scheme != nil {
            return absoluteURL.absoluteString
        }

        guard baseURL.isFileURL else {
            return destination
        }

        let resolved = URL(fileURLWithPath: destination, relativeTo: baseURL).standardizedFileURL
        return resolved.absoluteString
    }

    private static func previewImageDestination(_ destination: String, baseURL: URL?) -> String {
        if let absoluteURL = URL(string: destination), absoluteURL.scheme != nil {
            return absoluteURL.absoluteString
        }

        guard let baseURL, baseURL.isFileURL else {
            return destination
        }

        let resolvedURL = URL(fileURLWithPath: destination, relativeTo: baseURL).standardizedFileURL
        guard let embeddedURL = embeddedImageDataURL(for: resolvedURL) else {
            return resolvedURL.absoluteString
        }

        return embeddedURL
    }

    private static func embeddedImageDataURL(for fileURL: URL) -> String? {
        guard fileURL.isFileURL else { return nil }
        guard let imageMimeType = imageMimeType(for: fileURL.pathExtension) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }

        return "data:\(imageMimeType);base64,\(data.base64EncodedString())"
    }

    private static func imageMimeType(for pathExtension: String) -> String? {
        switch pathExtension.lowercased() {
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "svg":
            return "image/svg+xml"
        default:
            return nil
        }
    }
}

private let resourceBundle: Bundle = {
#if SWIFT_PACKAGE
    .module
#else
    .main
#endif
}()

private enum MarkdownBlock {
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedList([MarkdownListItem])
    case orderedList([MarkdownOrderedListItem])
    case blockQuote([String])
    case codeBlock(language: String?, code: String)
    case table(header: [String], alignments: [MarkdownTableAlignment], rows: [[String]])
    case thematicBreak
}

private struct MarkdownListItem {
    enum Kind {
        case plain
        case task(Bool)
    }

    let kind: Kind
    let text: String
}

private struct MarkdownOrderedListItem {
    let number: String
    let text: String
}

private enum MarkdownTableAlignment {
    case left
    case center
    case right
}

private enum MarkdownBlockParser {
    static func parse(_ source: String) -> [MarkdownBlock] {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [MarkdownBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]

            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
                continue
            }

            if let fence = codeFence(line) {
                let parsed = parseCodeBlock(lines: lines, start: index, fence: fence)
                blocks.append(.codeBlock(language: parsed.language, code: parsed.code))
                index = parsed.nextIndex
                continue
            }

            if let heading = heading(line) {
                blocks.append(.heading(level: heading.level, text: heading.text))
                index += 1
                continue
            }

            if isThematicBreak(line) {
                blocks.append(.thematicBreak)
                index += 1
                continue
            }

            if isTableHeader(lines: lines, index: index) {
                let parsed = parseTable(lines: lines, start: index)
                blocks.append(.table(header: parsed.header, alignments: parsed.alignments, rows: parsed.rows))
                index = parsed.nextIndex
                continue
            }

            if unorderedListItem(line) != nil {
                let parsed = parseUnorderedList(lines: lines, start: index)
                blocks.append(.unorderedList(parsed.items))
                index = parsed.nextIndex
                continue
            }

            if orderedListItem(line) != nil {
                let parsed = parseOrderedList(lines: lines, start: index)
                blocks.append(.orderedList(parsed.items))
                index = parsed.nextIndex
                continue
            }

            if isBlockQuoteLine(line) {
                let parsed = parseQuote(lines: lines, start: index)
                blocks.append(.blockQuote(parsed.paragraphs))
                index = parsed.nextIndex
                continue
            }

            let parsed = parseParagraph(lines: lines, start: index)
            blocks.append(.paragraph(parsed.text))
            index = parsed.nextIndex
        }

        return blocks
    }

    private static func parseCodeBlock(
        lines: [String],
        start: Int,
        fence: MarkdownFence
    ) -> (language: String?, code: String, nextIndex: Int) {
        var index = start + 1
        var codeLines: [String] = []

        while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces) != fence.closingFence {
            codeLines.append(lines[index])
            index += 1
        }

        if index < lines.count {
            index += 1
        }

        return (fence.language, codeLines.joined(separator: "\n"), index)
    }

    private static func parseParagraph(lines: [String], start: Int) -> (text: String, nextIndex: Int) {
        var collected: [String] = []
        var index = start
        var previousLine: String?

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty || startsNewBlock(lines: lines, index: index) {
                break
            }

            let trimmed = normalizedParagraphLine(line)
            if collected.isEmpty {
                collected.append(trimmed)
            } else if let previousLine, hasHardLineBreak(previousLine) {
                let last = collected.removeLast()
                collected.append(last + "\n" + trimmed)
            } else {
                let last = collected.removeLast()
                collected.append(last + " " + trimmed)
            }

            previousLine = line
            index += 1
        }

        return (collected.last ?? "", index)
    }

    private static func parseQuote(lines: [String], start: Int) -> (paragraphs: [String], nextIndex: Int) {
        var rawLines: [String] = []
        var index = start

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                rawLines.append("")
                index += 1
                continue
            }

            guard isBlockQuoteLine(line) else { break }
            rawLines.append(stripQuotePrefix(line))
            index += 1
        }

        return (splitIntoParagraphs(rawLines), index)
    }

    private static func parseUnorderedList(lines: [String], start: Int) -> (items: [MarkdownListItem], nextIndex: Int) {
        var items: [MarkdownListItem] = []
        var index = start

        while index < lines.count {
            guard let item = unorderedListItem(lines[index]) else { break }
            items.append(item)
            index += 1
        }

        return (items, index)
    }

    private static func parseOrderedList(lines: [String], start: Int) -> (items: [MarkdownOrderedListItem], nextIndex: Int) {
        var items: [MarkdownOrderedListItem] = []
        var index = start

        while index < lines.count {
            guard let item = orderedListItem(lines[index]) else { break }
            items.append(item)
            index += 1
        }

        return (items, index)
    }

    private static func parseTable(
        lines: [String],
        start: Int
    ) -> (header: [String], alignments: [MarkdownTableAlignment], rows: [[String]], nextIndex: Int) {
        let header = splitTableRow(lines[start])
        let alignments = parseTableAlignments(lines[start + 1])
        var rows: [[String]] = []
        var index = start + 2

        while index < lines.count {
            let line = lines[index]
            if line.trimmingCharacters(in: .whitespaces).isEmpty || line.contains("|") == false {
                break
            }

            rows.append(splitTableRow(line))
            index += 1
        }

        return (header, alignments, rows, index)
    }

    private static func splitIntoParagraphs(_ lines: [String]) -> [String] {
        var paragraphs: [String] = []
        var current: [String] = []
        var previousLine: String?

        for line in lines {
            if line.isEmpty {
                if current.isEmpty == false {
                    paragraphs.append(current.last ?? "")
                    current.removeAll()
                    previousLine = nil
                }
                continue
            }

            let trimmed = normalizedParagraphLine(line)
            if current.isEmpty {
                current.append(trimmed)
            } else if let previousLine, hasHardLineBreak(previousLine) {
                let last = current.removeLast()
                current.append(last + "\n" + trimmed)
            } else {
                let last = current.removeLast()
                current.append(last + " " + trimmed)
            }

            previousLine = line
        }

        if current.isEmpty == false {
            paragraphs.append(current.last ?? "")
        }

        return paragraphs
    }

    private static func startsNewBlock(lines: [String], index: Int) -> Bool {
        let line = lines[index]
        return codeFence(line) != nil
            || heading(line) != nil
            || isThematicBreak(line)
            || isTableHeader(lines: lines, index: index)
            || unorderedListItem(line) != nil
            || orderedListItem(line) != nil
            || isBlockQuoteLine(line)
    }

    private static func heading(_ line: String) -> (level: Int, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }

        let hashes = trimmed.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else { return nil }

        let remainder = trimmed.dropFirst(hashes.count).trimmingCharacters(in: .whitespaces)
        guard remainder.isEmpty == false else { return nil }
        let text = remainder.replacingOccurrences(of: #"\s#+\s*$"#, with: "", options: .regularExpression)
        return (hashes.count, text)
    }

    private static func codeFence(_ line: String) -> MarkdownFence? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("```") else { return nil }

        let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        return MarkdownFence(closingFence: "```", language: language.isEmpty ? nil : language)
    }

    private static func isBlockQuoteLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).hasPrefix(">")
    }

    private static func stripQuotePrefix(_ line: String) -> String {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(">") else { return trimmed }
        trimmed.removeFirst()
        if trimmed.hasPrefix(" ") {
            trimmed.removeFirst()
        }
        return trimmed
    }

    private static func unorderedListItem(_ line: String) -> MarkdownListItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return nil }

        let marker = trimmed.prefix(2)
        guard marker == "- " || marker == "* " || marker == "+ " else { return nil }

        let content = String(trimmed.dropFirst(2))
        if content.hasPrefix("[x] ") || content.hasPrefix("[X] ") {
            return MarkdownListItem(kind: .task(true), text: String(content.dropFirst(4)))
        }

        if content.hasPrefix("[ ] ") {
            return MarkdownListItem(kind: .task(false), text: String(content.dropFirst(4)))
        }

        return MarkdownListItem(kind: .plain, text: content)
    }

    private static func orderedListItem(_ line: String) -> MarkdownOrderedListItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }

        let number = String(trimmed[..<dotIndex])
        guard number.isEmpty == false, number.allSatisfy(\.isNumber) else { return nil }

        let textStart = trimmed.index(after: dotIndex)
        guard textStart < trimmed.endIndex, trimmed[textStart] == " " else { return nil }
        let text = String(trimmed[trimmed.index(after: textStart)...])
        return MarkdownOrderedListItem(number: number, text: text)
    }

    private static func isTableHeader(lines: [String], index: Int) -> Bool {
        guard index + 1 < lines.count else { return false }
        let header = lines[index].trimmingCharacters(in: .whitespaces)
        let separator = lines[index + 1].trimmingCharacters(in: .whitespaces)
        return header.contains("|") && isTableSeparator(separator)
    }

    private static func splitTableRow(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }
        return trimmed
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func parseTableAlignments(_ line: String) -> [MarkdownTableAlignment] {
        splitTableRow(line).map { column in
            let trimmed = column.trimmingCharacters(in: .whitespaces)
            let left = trimmed.hasPrefix(":")
            let right = trimmed.hasSuffix(":")

            if left && right {
                return .center
            }

            if right {
                return .right
            }

            return .left
        }
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let columns = splitTableRow(line)
        guard columns.isEmpty == false else { return false }
        return columns.allSatisfy { column in
            let trimmed = column
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ":", with: "")
            return trimmed.isEmpty == false && trimmed.allSatisfy { $0 == "-" }
        }
    }

    private static func isThematicBreak(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let compact = trimmed.replacingOccurrences(of: " ", with: "")
        guard compact.count >= 3 else { return false }
        return Set(compact).count == 1 && ["-", "*", "_"].contains(compact.first.map(String.init) ?? "")
    }

    private static func hasHardLineBreak(_ line: String) -> Bool {
        line.hasSuffix("\\") || line.hasSuffix("  ")
    }

    private static func normalizedParagraphLine(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix("\\") else { return trimmed }
        return String(trimmed.dropLast())
    }
}

private struct MarkdownFence {
    let closingFence: String
    let language: String?
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
