import AppKit

/// Invisible window that sits over the notch area to detect hover and clicks
final class NotchHoverZone: NSPanel {

    private var hoverView: HoverDetectionView!
    private var onActivate: (() -> Void)?

    init(onActivate: @escaping () -> Void) {
        self.onActivate = onActivate

        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        setupHoverView()
        positionAtNotch()

        // Listen for screen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    private func configurePanel() {
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]
    }

    private func setupHoverView() {
        hoverView = HoverDetectionView { [weak self] in
            self?.onActivate?()
        }
        contentView = hoverView
    }

    func positionAtNotch() {
        guard let screen = NSScreen.main else { return }
        let frame = ScreenUtilities.notchHoverFrame(screen: screen)
        setFrame(frame, display: true)
    }

    @objc private func screenDidChange() {
        positionAtNotch()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - Hover Detection View

private final class HoverDetectionView: NSView {

    private var trackingArea: NSTrackingArea?
    private var tooltipWindow: TooltipWindow?
    private var onActivate: (() -> Void)?
    private var isHovering = false

    init(onActivate: @escaping () -> Void) {
        self.onActivate = onActivate
        super.init(frame: .zero)
        setupTracking()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupTracking() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .enabledDuringMouseDrag],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        showTooltip()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        hideTooltip()
    }

    override func mouseDown(with event: NSEvent) {
        hideTooltip()
        onActivate?()
    }

    private func showTooltip() {
        guard tooltipWindow == nil else { return }

        tooltipWindow = TooltipWindow(text: "Click to open terminal")

        guard let screen = NSScreen.main else { return }
        let menuHeight = ScreenUtilities.menuBarHeight(screen: screen)
        let tooltipSize = tooltipWindow!.frame.size

        let x = screen.frame.midX - (tooltipSize.width / 2)
        let y = screen.frame.maxY - menuHeight - tooltipSize.height - 8

        tooltipWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        tooltipWindow?.orderFront(nil)

        // Fade in
        tooltipWindow?.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            tooltipWindow?.animator().alphaValue = 1
        }
    }

    private func hideTooltip() {
        guard let tooltip = tooltipWindow else { return }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            tooltip.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.tooltipWindow?.orderOut(nil)
            self?.tooltipWindow = nil
        }
    }
}

// MARK: - Tooltip Window

private final class TooltipWindow: NSWindow {

    init(text: String) {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        setupContent(text: text)
    }

    private func setupContent(text: String) {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = NSColor.white
        label.alignment = .center

        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.2, alpha: 0.95).cgColor
        container.layer?.cornerRadius = 6

        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
        ])

        contentView = container

        // Size to fit
        let size = NSSize(
            width: label.intrinsicContentSize.width + 20,
            height: label.intrinsicContentSize.height + 12
        )
        setContentSize(size)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
