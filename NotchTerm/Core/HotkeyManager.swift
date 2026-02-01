import AppKit
import HotKey

/// Manages global hotkey registration for terminal toggle
final class HotkeyManager {

    private var hotkey: HotKey?
    private let toggleHandler: () -> Void

    /// Initialize with a handler to call when hotkey is pressed
    /// - Parameter toggleHandler: Closure called when Ctrl+` is pressed
    init(toggleHandler: @escaping () -> Void) {
        self.toggleHandler = toggleHandler
        setupHotkey()
    }

    private func setupHotkey() {
        // Control + ` (grave/backtick)
        hotkey = HotKey(key: .grave, modifiers: [.control])
        hotkey?.keyDownHandler = { [weak self] in
            self?.toggleHandler()
        }
    }
}
