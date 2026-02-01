import AppKit

/// Custom NSPanel configured for floating above the notch/menubar area
final class NotchPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
    }

    private func configurePanel() {
        // Window level above menubar - use screenSaver level to appear above everything
        level = .screenSaver

        // Appearance - transparent window, content provides visuals
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false  // Shadow handled by content view

        // Behavior
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true

        // Collection behavior for proper space handling
        collectionBehavior = [
            .canJoinAllSpaces,  // Visible on all desktops
            .fullScreenAuxiliary,  // Works with fullscreen apps
            .stationary,  // Doesn't move with space transitions
            .ignoresCycle,  // Don't appear in Cmd+Tab
        ]

        // Animate frame changes smoothly
        animationBehavior = .utilityWindow
    }

    // Allow the panel to become key window for keyboard input
    override var canBecomeKey: Bool { true }

    // Prevent the panel from becoming main window
    override var canBecomeMain: Bool { false }
}
