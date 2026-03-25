import SwiftUI
import UIKit

struct SyntaxTextView: UIViewRepresentable {
    @Binding var text: String
    let attributedText: NSAttributedString
    let backgroundColor: UIColor
    var onTextChange: (String) -> Void

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.isEditable = true
        textView.isSelectable = true
        textView.backgroundColor = backgroundColor
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Only update if the text has actually changed to avoid cursor jumping
        if uiView.attributedText.string != text {
            uiView.attributedText = attributedText
        } else {
            // Update attributes even if string is same (for theme changes)
            let selectedRange = uiView.selectedRange
            uiView.attributedText = attributedText
            uiView.selectedRange = selectedRange
        }
        uiView.backgroundColor = backgroundColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: SyntaxTextView

        init(_ parent: SyntaxTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange(textView.text)
        }
    }
}
