import AppKit
import SwiftTerm

/// Manages the terminal window, shell process, and show/hide animations
final class TerminalWindowController: NSWindowController {

    // MARK: - Configuration

    private let config: Configuration
    private let cornerRadius: CGFloat = 16

    // Total height includes notch area
    private var terminalHeight: CGFloat {
        guard let screen = NSScreen.main else { return config.terminal.heightBelowNotch }
        return config.terminal.heightBelowNotch + ScreenUtilities.menuBarHeight(screen: screen)
    }

    // MARK: - State

    private var terminalView: LocalProcessTerminalView!
    private var containerView: NotchBlendingView!
    private(set) var isVisible = false
    private var shellRunning = false
    private var clickOutsideMonitor: Any?

    // MARK: - Initialization

    init(config: Configuration = .load()) {
        self.config = config
        let panel = NotchPanel(contentRect: .zero)
        super.init(window: panel)

        setupContainerView()
        setupTerminalView()
        positionWindow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupContainerView() {
        containerView = NotchBlendingView(
            cornerRadius: cornerRadius,
            backgroundColor: config.resolvedBackgroundColor(),
            opacity: config.theme.backgroundOpacity,
            blurRadius: config.theme.backgroundBlurRadius
        )
        window?.contentView = containerView

        // Add click zone at top for hiding when clicking notch area
        setupNotchClickZone()
    }

    private func setupNotchClickZone() {
        guard let screen = NSScreen.main else { return }
        let notchHeight = ScreenUtilities.menuBarHeight(screen: screen)

        let clickZone = NotchClickZone { [weak self] in
            self?.hide()
        }
        clickZone.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(clickZone)

        NSLayoutConstraint.activate([
            clickZone.topAnchor.constraint(equalTo: containerView.topAnchor),
            clickZone.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            clickZone.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            clickZone.heightAnchor.constraint(equalToConstant: notchHeight),
        ])
    }

    private func setupTerminalView() {
        terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        terminalView.processDelegate = self

        // Terminal appearance from config
        // Terminal background is always transparent - the panel provides the background
        terminalView.nativeBackgroundColor = NSColor.clear
        terminalView.nativeForegroundColor = config.resolvedForegroundColor()
        terminalView.font = config.resolvedFont()

        // Force the terminal layer to be transparent
        terminalView.wantsLayer = true
        terminalView.layer?.backgroundColor = NSColor.clear.cgColor
        terminalView.layer?.isOpaque = false

        // Apply ANSI color palette
        terminalView.installColors(config.resolvedAnsiColors())

        // Apply selection color
        terminalView.selectedTextBackgroundColor = config.resolvedSelectionBackgroundColor()

        containerView.addSubview(terminalView)

        // Calculate top padding to account for notch/menubar area
        let topPadding: CGFloat
        if let screen = NSScreen.main {
            topPadding = ScreenUtilities.menuBarHeight(screen: screen) + 6
        } else {
            topPadding = 38  // Fallback for notch height + padding
        }

        // Constraints with padding (top padding clears the notch area)
        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(
                equalTo: containerView.topAnchor, constant: topPadding),
            terminalView.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor, constant: 12),
            terminalView.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor, constant: -12),
            terminalView.bottomAnchor.constraint(
                equalTo: containerView.bottomAnchor, constant: -14),
        ])
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        // Always position at full size - we use layer transforms for zoom animation
        let frame = ScreenUtilities.terminalFrame(
            screen: screen,
            width: config.terminal.width,
            height: terminalHeight
        )
        window?.setFrame(frame, display: false)
    }

    // MARK: - Shell Management

    private func startShell() {
        // Use tmux to create or attach to a persistent session
        let tmuxPath = "/opt/homebrew/bin/tmux"
        let fallbackTmuxPath = "/usr/local/bin/tmux"
        let sessionName = "NotchTerm"

        // Check which tmux path exists
        let tmux = FileManager.default.fileExists(atPath: tmuxPath) ? tmuxPath : fallbackTmuxPath

        // Build environment with essential variables
        var environment = ProcessInfo.processInfo.environment

        // Ensure HOME is set
        if environment["HOME"] == nil {
            environment["HOME"] = NSHomeDirectory()
        }

        // Ensure SSH_AUTH_SOCK is inherited if available
        // (already included from ProcessInfo.processInfo.environment)

        // Set working directory to HOME
        let homeDirectory = environment["HOME"] ?? NSHomeDirectory()

        // tmux new-session -A -s NotchTerm -c $HOME
        // -A: attach if session exists, otherwise create new
        // -s: session name
        // -c: starting directory for new sessions
        terminalView.startProcess(
            executable: tmux,
            args: ["new-session", "-A", "-s", sessionName, "-c", homeDirectory],
            environment: Array(environment.map { "\($0.key)=\($0.value)" })
        )
        shellRunning = true
    }

    // MARK: - Public API

    /// Toggle terminal visibility
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Show the terminal with animation
    func show() {
        guard !isVisible else { return }
        isVisible = true

        // Start shell if not running
        if !shellRunning {
            startShell()
        }

        // Ensure positioned correctly before animating
        positionWindow()
        window?.orderFrontRegardless()

        animateIn()
        startClickOutsideMonitor()
    }

    /// Hide the terminal with animation
    func hide() {
        guard isVisible else { return }
        isVisible = false

        stopClickOutsideMonitor()
        animateOut()
    }

    // MARK: - Click Outside Detection

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseDown, .rightMouseDown,
        ]) { [weak self] _ in
            guard let self = self, let window = self.window else { return }

            // Check if click is outside our window
            let screenLocation = NSEvent.mouseLocation
            if !window.frame.contains(screenLocation) {
                self.hide()
            }
        }
    }

    private func stopClickOutsideMonitor() {
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
    }

    // MARK: - Zoom Animations

    /// Calculate scale factors for zoom animation from notch
    private func zoomScales(screen: NSScreen) -> (scaleX: CGFloat, scaleY: CGFloat) {
        let collapsedFrame = ScreenUtilities.collapsedFrame(
            screen: screen, width: config.terminal.width)
        let targetFrame = ScreenUtilities.terminalFrame(
            screen: screen,
            width: config.terminal.width,
            height: terminalHeight
        )

        // Scale based on notch size / full size ratio
        let scaleX = collapsedFrame.width / targetFrame.width
        let scaleY = collapsedFrame.height / targetFrame.height

        return (scaleX, scaleY)
    }

    private func animateIn() {
        guard let window = window, let screen = NSScreen.main,
            let contentView = window.contentView,
            let layer = contentView.layer
        else { return }

        let scales = zoomScales(screen: screen)

        // Anchor at top center (where notch is)
        layer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        layer.position = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.maxY)

        // Start scaled down to notch size (both X and Y)
        layer.transform = CATransform3DMakeScale(scales.scaleX, scales.scaleY, 1.0)

        // Animate to full size
        CATransaction.begin()
        CATransaction.setAnimationDuration(config.animation.duration)
        CATransaction.setAnimationTimingFunction(
            CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0))
        CATransaction.setCompletionBlock { [weak self] in
            self?.window?.makeKey()
            self?.terminalView.window?.makeFirstResponder(self?.terminalView)
        }

        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = layer.transform
        animation.toValue = CATransform3DIdentity
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        layer.add(animation, forKey: "zoomIn")
        layer.transform = CATransform3DIdentity

        CATransaction.commit()
    }

    private func animateOut() {
        guard let window = window, let screen = NSScreen.main,
            let contentView = window.contentView,
            let layer = contentView.layer
        else { return }

        let scales = zoomScales(screen: screen)

        // Anchor at top center (where notch is)
        layer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        layer.position = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.maxY)

        // Animate to scaled down (notch size)
        CATransaction.begin()
        CATransaction.setAnimationDuration(config.animation.duration * 0.5)
        CATransaction.setAnimationTimingFunction(
            CAMediaTimingFunction(controlPoints: 0.4, 0.0, 1.0, 1.0))
        CATransaction.setCompletionBlock { [weak self] in
            self?.window?.orderOut(nil)
            // Reset transform for next show
            layer.transform = CATransform3DIdentity
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }

        let targetTransform = CATransform3DMakeScale(scales.scaleX, scales.scaleY, 1.0)

        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = CATransform3DIdentity
        animation.toValue = targetTransform
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        layer.add(animation, forKey: "zoomOut")
        layer.transform = targetTransform

        CATransaction.commit()
    }
}

// MARK: - LocalProcessTerminalViewDelegate

extension TerminalWindowController: LocalProcessTerminalViewDelegate {

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        // Terminal handles resize internally
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        // Could update window title if desired
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        // Track working directory if needed
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        shellRunning = false
        // Restart shell when it exits
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startShell()
        }
    }
}

// MARK: - Notch Click Zone

/// Invisible view at the top of the terminal that hides it when clicked
private final class NotchClickZone: NSView {

    private var onClick: (() -> Void)?

    init(onClick: @escaping () -> Void) {
        self.onClick = onClick
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

// MARK: - Notch Blending View

/// Custom view that blends seamlessly with the notch
/// - Configurable background with opacity and blur
/// - Rounded corners only at the bottom
final class NotchBlendingView: NSView {

    private let cornerRadius: CGFloat
    private let backgroundColor: NSColor
    private let opacity: CGFloat
    private let blurRadius: CGFloat
    private var visualEffectView: NSVisualEffectView?
    private var colorOverlayLayer: CALayer?

    init(
        cornerRadius: CGFloat, backgroundColor: NSColor = .black, opacity: CGFloat = 1.0,
        blurRadius: CGFloat = 0
    ) {
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.opacity = opacity
        self.blurRadius = blurRadius
        super.init(frame: .zero)
        wantsLayer = true
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        guard let layer = layer else { return }

        // Main layer is transparent
        layer.backgroundColor = NSColor.clear.cgColor

        // Add blur effect view at the bottom
        if blurRadius > 0 {
            let effectView = NSVisualEffectView()
            effectView.translatesAutoresizingMaskIntoConstraints = false
            effectView.blendingMode = .behindWindow
            // Use hudWindow for dark blur that matches terminal themes
            effectView.material = .hudWindow
            effectView.state = .active
            effectView.wantsLayer = true
            // Force dark appearance to prevent brightening
            effectView.appearance = NSAppearance(named: .darkAqua)

            addSubview(effectView, positioned: .below, relativeTo: nil)
            NSLayoutConstraint.activate([
                effectView.topAnchor.constraint(equalTo: topAnchor),
                effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
                effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
                effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            visualEffectView = effectView
        }

        // Add a color overlay layer on top of the blur
        // Use higher opacity to ensure the configured background color dominates
        let overlay = CALayer()
        let overlayOpacity = max(opacity, 0.85)  // Ensure at least 85% of the color shows
        overlay.backgroundColor = backgroundColor.withAlphaComponent(overlayOpacity).cgColor
        layer.addSublayer(overlay)
        colorOverlayLayer = overlay

        // Subtle shadow for depth
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: -5)
    }

    override func updateLayer() {
        super.updateLayer()
        updateMask()
    }

    override func layout() {
        super.layout()
        colorOverlayLayer?.frame = bounds
        updateMask()
    }

    private func updateMask() {
        // Create path with rounded bottom corners only
        let path = CGMutablePath()
        let rect = bounds

        // Top left (square corner)
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))

        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))

        // Right edge down to bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius))

        // Bottom-right rounded corner
        path.addArc(
            center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: 0,
            endAngle: -.pi / 2,
            clockwise: true
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY))

        // Bottom-left rounded corner
        path.addArc(
            center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: -.pi / 2,
            endAngle: -.pi,
            clockwise: true
        )

        // Left edge back to top
        path.closeSubpath()

        // Apply as mask to main layer
        let maskLayer = CAShapeLayer()
        maskLayer.path = path
        layer?.mask = maskLayer

        // Also mask the visual effect view if present
        if let effectView = visualEffectView {
            let effectMask = CAShapeLayer()
            effectMask.path = path
            effectView.layer?.mask = effectMask
        }

        // Also mask the color overlay
        if let overlay = colorOverlayLayer {
            let overlayMask = CAShapeLayer()
            overlayMask.path = path
            overlay.mask = overlayMask
        }
    }
}
