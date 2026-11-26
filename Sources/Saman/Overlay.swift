import AppKit
import SwiftUI
import Translation

private final class OverlayPanel: NSPanel {
    var onEscape: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown && event.keyCode == 53 {
            onEscape?()
            return
        }
        super.sendEvent(event)
    }
}

@MainActor
final class Overlay: NSObject {
    private let icon = OverlayPanel(
        contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
    )
    private let result = OverlayPanel(
        contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false
    )
    private var iconAction: (() -> Void)?
    private var currentAnchor = CGPoint.zero
    private let accent = Color(red: 0.25, green: 0.31, blue: 0.85)
    static let iconSize = CGSize(width: 26, height: 26)

    var isShowingResult: Bool { result.isVisible }

    override init() {
        super.init()
        for panel in [icon, result] {
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .floating
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.isFloatingPanel = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.isReleasedWhenClosed = false
            panel.animationBehavior = .none
        }

        icon.setContentSize(Self.iconSize)
        icon.hasShadow = false
        let button = IconButton(frame: CGRect(origin: .zero, size: Self.iconSize))
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        button.contentTintColor = .white
        button.wantsLayer = true
        button.layer?.cornerRadius = 7
        button.layer?.backgroundColor = NSColor(accent).cgColor
        button.target = self
        button.action = #selector(translateSelection)
        icon.contentView = button
        updateLocalization()

        result.isMovable = true
        result.onEscape = { [weak self] in self?.dismissResult() }
    }

    func updateLocalization() {
        guard let button = icon.contentView as? NSButton else { return }
        button.image = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: localized("menu.selection"))
        button.toolTip = localized("bubble.tooltip")
    }

    private final class IconButton: NSButton {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }

    @objc private func translateSelection() { iconAction?() }

    func showIcon(near point: CGPoint, selectionBounds: CGRect?, action: @escaping () -> Void) {
        iconAction = action
        let bounds = selectionBounds.map(Self.appKitRect)
        let pointerScreen = Self.screen(at: point)
        let screen = if let bounds, !bounds.intersects(pointerScreen) {
            Self.screen(at: CGPoint(x: bounds.midX, y: bounds.midY))
        } else {
            pointerScreen
        }
        let frame = Self.iconFrame(near: point, selectionBounds: bounds, screen: screen)
        currentAnchor = CGPoint(x: frame.minX, y: frame.minY - 3)
        icon.setFrameOrigin(frame.origin)
        icon.orderFrontRegardless()
    }

    func showTranslation(_ text: TranslationText, near point: CGPoint? = nil) {
        let anchor = point ?? currentAnchor
        hideIcon()
        showResult(.init(source: text, close: { [weak self] in self?.dismissResult() }), at: anchor)
    }

    func showMessage(_ message: String, near point: CGPoint) {
        hideIcon()
        showResult(.init(message: message, close: { [weak self] in self?.dismissResult() }), at: point)
    }

    private func showResult(_ view: TranslationCard, at anchor: CGPoint) {
        let screen = Self.screen(at: anchor)
        let width = min(400, screen.width - 20)
        let sourceHeight = view.sourceHeight(at: width - 32)
        let height = min(215 + sourceHeight, screen.height - 20)
        let size = CGSize(width: width, height: height)
        let card = view.frame(width: size.width, height: size.height)
        result.contentView = NSHostingView(rootView: card)
        result.setFrame(CGRect(origin: Self.origin(for: size, anchor: anchor, screen: screen), size: size), display: true)
        result.makeKeyAndOrderFront(nil)
    }

    func contains(_ point: CGPoint) -> Bool {
        (icon.isVisible && icon.frame.contains(point)) || (result.isVisible && result.frame.contains(point))
    }

    func hideIcon() {
        icon.orderOut(nil)
        iconAction = nil
    }

    func dismissResult() {
        result.orderOut(nil)
        result.contentView = nil
    }

    func dismiss() {
        hideIcon()
        dismissResult()
    }

    static func accessibilityPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - point.y)
    }

    private static func appKitRect(_ bounds: CGRect) -> CGRect {
        CGRect(x: bounds.minX, y: accessibilityPoint(.init(x: 0, y: bounds.maxY)).y,
               width: bounds.width, height: bounds.height)
    }

    private static func screen(at point: CGPoint) -> CGRect {
        NSScreen.screens.first { $0.frame.contains(point) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? CGRect(x: 0, y: 0, width: 1024, height: 768)
    }

    static func iconFrame(near point: CGPoint, selectionBounds: CGRect?, screen: CGRect) -> CGRect {
        let size = iconSize
        let gap: CGFloat = 3
        let screen = screen.insetBy(dx: 4, dy: 4)

        func frame(x: CGFloat, y: CGFloat) -> CGRect {
            CGRect(
                x: max(screen.minX, min(x, screen.maxX - size.width)),
                y: max(screen.minY, min(y, screen.maxY - size.height)),
                width: size.width,
                height: size.height
            )
        }

        if let bounds = selectionBounds?.intersection(screen), !bounds.isEmpty {
            let left = bounds.minX - gap - size.width
            let right = bounds.maxX + gap
            let y = min(bounds.maxY, max(point.y, bounds.minY)) - size.height / 2
            if point.x >= bounds.maxX - 8, right + size.width <= screen.maxX {
                return frame(x: right, y: y)
            }
            if point.x <= bounds.minX + 8, left >= screen.minX {
                return frame(x: left, y: y)
            }

            let x = min(bounds.maxX, max(point.x, bounds.minX)) - size.width / 2
            let below = bounds.minY - gap - size.height
            let above = bounds.maxY + gap
            let roomBelow = below >= screen.minY
            let roomAbove = above + size.height <= screen.maxY
            if roomBelow && (!roomAbove || point.y <= bounds.midY) { return frame(x: x, y: below) }
            if roomAbove { return frame(x: x, y: above) }
        }

        let right = point.x + gap
        let x = right + size.width <= screen.maxX ? right : point.x - gap - size.width
        return frame(x: x, y: point.y - size.height / 2)
    }

    static func origin(for size: CGSize, anchor: CGPoint, screen: CGRect) -> CGPoint {
        let frame = screen.insetBy(dx: 8, dy: 8)
        let below = anchor.y - size.height
        let preferredY = below >= frame.minY ? below : anchor.y + 20
        return CGPoint(
            x: max(frame.minX, min(anchor.x, frame.maxX - size.width)),
            y: max(frame.minY, min(preferredY, frame.maxY - size.height))
        )
    }
}

private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DragView()
        view.toolTip = localized("panel.drag")
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

private struct TranslationCard: View {
    private var source: TranslationText? { state.source }
    private let close: () -> Void

    @ObservedObject private var state: CardState

    private final class CardState: ObservableObject {
        @Published var source: TranslationText?
        @Published var configuration: TranslationSession.Configuration?
        @Published var translated: String?
        @Published var message: String?
        @Published var canRetry = false
        @Published var copied = false

        init(source: TranslationText?, message: String?) {
            self.source = source
            self.configuration = source.map { .init(source: $0.source.locale, target: $0.target.locale) }
            self.message = message
        }

        func swapDirection() {
            guard let text = source?.reversed else { return }
            translated = nil
            message = nil
            canRetry = false
            copied = false
            source = text
            configuration = .init(source: text.source.locale, target: text.target.locale)
        }
    }

    init(source: TranslationText? = nil, message: String? = nil, close: @escaping () -> Void) {
        self.close = close
        self.state = CardState(source: source, message: message)
    }

    func sourceHeight(at width: CGFloat) -> CGFloat {
        guard let source else { return 0 }
        let bounds = (source.value as NSString).boundingRect(
            with: CGSize(width: width, height: 62),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: NSFont.systemFont(ofSize: 13)]
        )
        return min(62, ceil(bounds.height) + 2)
    }

    var body: some View {
        GeometryReader { geometry in
            content(sourceHeight: sourceHeight(at: geometry.size.width - 32))
        }
    }

    private func content(sourceHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "character.bubble")
                    if let source {
                        Text(verbatim: source.source.displayName)
                        Image(systemName: "arrow.forward")
                        Text(verbatim: source.target.displayName)
                    } else {
                        Text(localized("panel.title"))
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                .padding(.leading, 16)
                .overlay { WindowDragArea().accessibilityHidden(true) }

                if source != nil {
                    Button {
                        state.swapDirection()
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(localized("panel.reverse"))
                    .help(localized("panel.reverse"))
                }

                Button(action: close) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(localized("panel.close"))
                .help(localized("panel.close"))
                .padding(.trailing, 16)
            }

            Divider()

            if let source {
                ScrollView {
                    Text(verbatim: source.value)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, source.source.isRightToLeft ? .rightToLeft : .leftToRight)
                }
                .frame(height: sourceHeight)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                Divider()
            }

            if let content = state.translated ?? state.message {
                let direction = if state.translated != nil, let target = source?.target {
                    target.isRightToLeft ? LayoutDirection.rightToLeft : .leftToRight
                } else {
                    InterfaceLanguage.current.layoutDirection
                }
                ScrollView {
                    Text(verbatim: content)
                        .font(.system(size: state.translated == nil ? 14 : 20, weight: .medium))
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.layoutDirection, direction)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxHeight: .infinity)
            } else {
                HStack(spacing: 8) {
                    Text(localized("panel.loading"))
                    ProgressView().controlSize(.small)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let translated = state.translated {
                footer {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(translated, forType: .string)
                        state.copied = true
                    } label: {
                        Label(state.copied ? localized("panel.copied") : localized("panel.copy"), systemImage: state.copied ? "checkmark" : "document.on.document")
                    }
                }
            } else if state.canRetry {
                footer {
                    Button(localized("panel.retry")) {
                        state.canRetry = false
                        state.message = nil
                        state.configuration?.invalidate()
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.12), lineWidth: 1) }
        .environment(\.layoutDirection, InterfaceLanguage.current.layoutDirection)
        .environment(\.locale, InterfaceLanguage.current.locale)
        .translationTask(state.configuration) { session in
            guard let source else { return }
            let availability = await LanguageAvailability().status(from: source.source.locale, to: source.target.locale)
            guard !Task.isCancelled, state.source?.source == source.source else { return }
            if availability == .unsupported {
                state.message = localized("panel.unsupported")
                return
            }

            do {
                let response = try await session.translate(source.value)
                guard !Task.isCancelled, state.source?.source == source.source else { return }
                state.translated = response.targetText
            } catch {
                guard !Task.isCancelled, state.source?.source == source.source else { return }
                state.message = localized("panel.failed")
                state.canRetry = true
            }
        }
    }

    private func footer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                content()
                    .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
    }
}
