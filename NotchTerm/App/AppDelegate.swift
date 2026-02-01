import AppKit

/// Application delegate handling lifecycle and component initialization
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var terminalController: TerminalWindowController!
    private var hotkeyManager: HotkeyManager!
    private var hoverZone: NotchHoverZone!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (no dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Initialize components
        setupTerminalController()
        setupHoverZone()
        setupHotkey()
        setupStatusItem()
    }

    // MARK: - Setup

    private func setupTerminalController() {
        terminalController = TerminalWindowController()
    }

    private func setupHoverZone() {
        hoverZone = NotchHoverZone { [weak self] in
            self?.terminalController.toggle()
        }
        hoverZone.orderFront(nil)
    }

    private func setupHotkey() {
        hotkeyManager = HotkeyManager { [weak self] in
            self?.terminalController.toggle()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "terminal", accessibilityDescription: "NotchTerm")
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "Toggle Terminal",
            action: #selector(toggleTerminal),
            keyEquivalent: "`"
        )
        toggleItem.keyEquivalentModifierMask = .control
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(
            NSMenuItem(
                title: "Quit NotchTerm",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            ))

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleTerminal() {
        terminalController.toggle()
    }
}
