import SwiftUI
import UIKit

/// Native editing and selection, with presentation derived from the exercise preferences.
struct ExerciseTextEditor: UIViewRepresentable {
    let store: AppStore
    @Environment(\.dynamicTypeSize) private var typeSize

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView(usingTextLayoutManager: false)
        view.backgroundColor = UIColor(Theme.background)
        view.tintColor = UIColor(Theme.accent)
        view.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 24, right: 20)
        view.textContainer.lineFragmentPadding = 0
        view.keyboardDismissMode = .interactive
        view.autocapitalizationType = .none
        view.autocorrectionType = .no
        view.smartQuotesType = .no
        view.smartDashesType = .no
        view.allowsEditingTextAttributes = false
        view.adjustsFontForContentSizeCategory = true
        view.accessibilityLabel = "Exercise library"
        view.accessibilityHint = "One exercise per line. Highlight one or more complete exercise names to show Mute and Boost above the keyboard. Changes save automatically."
        view.accessibilityIdentifier = "library-editor"
        view.delegate = context.coordinator
        view.inputAccessoryView = context.coordinator.toolbar
        context.coordinator.textView = view
        context.coordinator.render()
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        // Read observable values here so preference changes trigger a new render.
        _ = store.data.libraryText
        _ = store.data.exercisePreferences
        _ = typeSize
        context.coordinator.render()
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        let store: AppStore
        weak var textView: UITextView?
        private var isRendering = false
        private var renderedText: String?
        private var renderedPreferences: [String: ExercisePreferences]?
        private var renderedFontSize: CGFloat?

        lazy var toolbar: ExerciseKeyboardToolbar = {
            let bar = ExerciseKeyboardToolbar()
            bar.mute.addTarget(self, action: #selector(toggleMute), for: .touchUpInside)
            bar.boost.addTarget(self, action: #selector(toggleBoost), for: .touchUpInside)
            bar.done.addTarget(self, action: #selector(done), for: .touchUpInside)
            return bar
        }()

        init(store: AppStore) { self.store = store }

        func textViewDidChange(_ textView: UITextView) {
            guard !isRendering, textView.markedTextRange == nil else { return }
            renderedText = nil // Reapply styles even when selected text is replaced with identical text.
            store.setLibraryText(textView.text)
            render()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isRendering else { return }
            updateToolbar()
        }

        func textViewDidBeginEditing(_ textView: UITextView) { updateToolbar() }
        func textViewDidEndEditing(_ textView: UITextView) { store.flushLibrary() }

        private var selectedKeys: Set<String> {
            guard let textView, textView.markedTextRange == nil else { return [] }
            return LibraryLines.selectedKeys(in: textView.text, range: textView.selectedRange)
        }

        @objc private func toggleMute() { toggle(\.isMuted) }
        @objc private func toggleBoost() { toggle(\.isBoosted) }
        @objc private func done() { textView?.resignFirstResponder() }

        private func toggle(_ preference: WritableKeyPath<ExercisePreferences, Bool>) {
            guard textView?.markedTextRange == nil else { return }
            store.toggleLibraryPreference(preference, keys: selectedKeys)
            render()
        }

        func render() {
            guard let textView, textView.markedTextRange == nil else { return }
            let fontSize = UIFont.preferredFont(forTextStyle: .body, compatibleWith: textView.traitCollection).pointSize
            guard renderedText != store.data.libraryText || renderedPreferences != store.data.exercisePreferences || renderedFontSize != fontSize else {
                updateToolbar()
                return
            }
            isRendering = true
            let selection = textView.selectedRange
            let offset = textView.contentOffset
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 7
            let normal: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: UIColor(Theme.foreground),
                .paragraphStyle: paragraph
            ]
            // Set attributes in place: replacing attributedText would reset the native undo stack.
            textView.textStorage.beginEditing()
            if textView.text != store.data.libraryText { textView.text = store.data.libraryText }
            textView.textStorage.setAttributes(normal, range: NSRange(location: 0, length: textView.textStorage.length))
            for line in LibraryLines.lines(in: store.data.libraryText) {
                let options = store.data.exercisePreferences[line.key] ?? ExercisePreferences()
                if options.isBoosted {
                    textView.textStorage.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .bold), range: line.range)
                }
                if options.isMuted {
                    textView.textStorage.addAttributes([
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .foregroundColor: UIColor(Theme.secondary)
                    ], range: line.range)
                }
            }
            textView.textStorage.endEditing()
            let start = min(selection.location, textView.textStorage.length)
            textView.selectedRange = NSRange(location: start, length: min(selection.length, textView.textStorage.length - start))
            textView.typingAttributes = normal
            textView.setContentOffset(offset, animated: false)
            renderedText = store.data.libraryText
            renderedPreferences = store.data.exercisePreferences
            renderedFontSize = fontSize
            isRendering = false
            updateToolbar()
        }

        private func updateToolbar() {
            let keys = selectedKeys
            let muted = !keys.isEmpty && keys.allSatisfy { store.data.exercisePreferences[$0]?.isMuted == true }
            let boosted = !keys.isEmpty && keys.allSatisfy { store.data.exercisePreferences[$0]?.isBoosted == true }
            let names = LibraryParser.parse(store.data.libraryText).filter { keys.contains(LibraryParser.key(for: $0)) }
            let context = names.count == 1 ? names[0] : "\(names.count) selected exercises"
            toolbar.update(showActions: !keys.isEmpty, muted: muted, boosted: boosted, context: context)
        }
    }
}

@MainActor
final class ExerciseKeyboardToolbar: UIInputView {
    let mute = UIButton(type: .system)
    let boost = UIButton(type: .system)
    let done = UIButton(type: .system)

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 390, height: 60), inputViewStyle: .keyboard)
        backgroundColor = UIColor(Theme.surface)
        let stack = UIStackView(arrangedSubviews: [mute, boost, UIView(), done])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
        for button in [mute, boost, done] {
            button.heightAnchor.constraint(equalToConstant: 44).isActive = true
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        mute.accessibilityIdentifier = "mute-exercise"
        boost.accessibilityIdentifier = "boost-exercise"
        done.accessibilityIdentifier = "done-editing-library"
        configure(done, title: "Done", active: false)
        update(showActions: false, muted: false, boosted: false, context: "")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(showActions: Bool, muted: Bool, boosted: Bool, context: String) {
        configure(mute, title: muted ? "Unmute" : "Mute", active: muted)
        configure(boost, title: boosted ? "Unboost" : "Boost 2×", active: boosted)
        mute.isHidden = !showActions
        boost.isHidden = !showActions
        mute.isEnabled = showActions
        boost.isEnabled = showActions
        mute.accessibilityValue = muted ? "Muted" : "In rotation"
        boost.accessibilityValue = boosted ? "Double weight" : "Normal weight"
        mute.accessibilityHint = "\(context). \(muted ? "Return to rotation." : "Exclude from new snacks and rerolls.")"
        boost.accessibilityHint = "\(context). \(boosted ? "Restore normal selection weight." : "Give double selection weight when unmuted.")"
    }

    private func configure(_ button: UIButton, title: String, active: Bool) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseForegroundColor = active ? UIColor(Theme.background) : UIColor(Theme.accent)
        configuration.baseBackgroundColor = active ? UIColor(Theme.accent) : UIColor(Theme.control)
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { input in
            var result = input
            result.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 15, weight: .semibold), maximumPointSize: 20)
            return result
        }
        button.configuration = configuration
    }
}
