import AppKit
import SwiftUI

struct HighlightingTextView: NSViewRepresentable {
    let attributedString: NSAttributedString
    let backgroundColor: NSColor

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isRichText = true
        textView.drawsBackground = true
        textView.backgroundColor = backgroundColor
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.backgroundColor = backgroundColor
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        scrollView.backgroundColor = backgroundColor
        textView.backgroundColor = backgroundColor
        textView.textStorage?.setAttributedString(attributedString)
    }
}
