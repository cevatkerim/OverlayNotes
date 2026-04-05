import Foundation
import Testing
@testable import OverlayNotes

struct MarkdownRendererTests {
    @Test
    func rendersBlockHTML() {
        let source = """
        # Title

        Paragraph one.  
        Next line.

        - First item
        - [x] Done

        1. Open the note
        2. Switch to Preview

        > Quoted text

        ```swift
        let value = 1
        ```

        | Feature | Expected |
        | :------ | -------: |
        | List    | Proper bullets |
        """

        let rendered = MarkdownRenderer.renderHTMLBody(source, baseURL: nil)

        #expect(rendered.contains("<h1>Title</h1>"))
        #expect(rendered.contains("<p>Paragraph one.\nNext line.</p>"))
        #expect(rendered.contains("<ul>"))
        #expect(rendered.contains("&#x2611;"))
        #expect(rendered.contains("<ol>"))
        #expect(rendered.contains("<blockquote><p>Quoted text</p></blockquote>"))
        #expect(rendered.contains("<div class=\"code-language\">swift</div><pre><code>let value = 1</code></pre>"))
        #expect(rendered.contains("<table>"))
        #expect(rendered.contains("style=\"text-align: left;\""))
        #expect(rendered.contains("style=\"text-align: right;\""))
    }

    @Test
    func resolvesRelativeImagesAgainstBaseURL() {
        let baseURL = URL(fileURLWithPath: "/tmp/notes/", isDirectory: true)
        let rendered = MarkdownRenderer.renderHTMLBody("![Alt text](./images/test1.png)", baseURL: baseURL)

        #expect(rendered.contains("<img "))
        #expect(rendered.contains("alt=\"Alt text\""))
        #expect(rendered.contains("src=\"file:///tmp/notes/images/test1.png\""))
    }

    @Test
    func scalesBaseFontSize() {
        #expect(MarkdownRenderer.baseFontSize(textScale: 1.0, isOverlay: false) == 16.0)
        #expect(MarkdownRenderer.baseFontSize(textScale: 0.1, isOverlay: false) == 13.0)
        #expect(abs(MarkdownRenderer.baseFontSize(textScale: 1.2, isOverlay: true) - 21.6) < 0.0001)
    }

    @Test
    func htmlDocumentInlinesBundledMarkdownIt() {
        let html = MarkdownRenderer.htmlDocument()

        #expect(html.contains("window.markdownit"))
        #expect(html.contains("window.markdownitEmoji"))
        #expect(html.contains("window.markdownitFootnote"))
        #expect(html.contains("window.markdownitTaskLists"))
        #expect(html.contains(".md-github__body"))
        #expect(html.contains("window.__overlayNotesParser"))
        #expect(html.contains("window.__overlayNotesGetScrollProgress"))
        #expect(html.contains("window.__overlayNotesGetScrollState"))
        #expect(html.contains("window.__overlayNotesResolveEdgeAffinity"))
        #expect(html.contains("window.__overlayNotesSetScrollProgress"))
        #expect(html.contains("messageHandlers.overlayNotesScroll"))
        #expect(html.contains("script src=") == false)
    }
}
