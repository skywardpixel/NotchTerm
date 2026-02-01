import AppKit

/// Utilities for notch detection and screen positioning
enum ScreenUtilities {

    /// Approximate notch width on MacBook Pro/Air displays
    static let notchWidth: CGFloat = 180

    /// Height of the notch/menubar area
    static func menuBarHeight(screen: NSScreen) -> CGFloat {
        let safeTop = screen.safeAreaInsets.top
        return safeTop > 0 ? safeTop : 24
    }

    /// Check if the given screen has a notch (MacBook Pro/Air with notch display)
    static func hasNotch(screen: NSScreen) -> Bool {
        screen.safeAreaInsets.top > 24
    }

    /// Get the notch hover zone frame (invisible clickable area)
    static func notchHoverFrame(screen: NSScreen) -> NSRect {
        let screenFrame = screen.frame
        let menuHeight = menuBarHeight(screen: screen)
        let width: CGFloat = hasNotch(screen: screen) ? notchWidth + 40 : 200

        return NSRect(
            x: screenFrame.midX - (width / 2),
            y: screenFrame.maxY - menuHeight,
            width: width,
            height: menuHeight
        )
    }

    /// Calculate the frame for the terminal window when shown
    /// Extends from the very top of the screen (into notch area)
    static func terminalFrame(screen: NSScreen, width: CGFloat, height: CGFloat) -> NSRect {
        let screenFrame = screen.frame

        // Center horizontally
        let x = screenFrame.midX - (width / 2)

        // Extend from the very top of the screen
        let y = screenFrame.maxY - height

        return NSRect(x: x, y: y, width: width, height: height)
    }

    /// Calculate the collapsed frame (hidden state) for the terminal window
    /// Small rectangle at the notch position for zoom animation origin
    static func collapsedFrame(screen: NSScreen, width: CGFloat) -> NSRect {
        let screenFrame = screen.frame
        let menuHeight = menuBarHeight(screen: screen)

        // Start as a small rectangle centered at the notch
        let collapsedWidth: CGFloat = hasNotch(screen: screen) ? notchWidth : 100
        let collapsedHeight: CGFloat = menuHeight

        let x = screenFrame.midX - (collapsedWidth / 2)
        let y = screenFrame.maxY - collapsedHeight

        return NSRect(x: x, y: y, width: collapsedWidth, height: collapsedHeight)
    }
}
