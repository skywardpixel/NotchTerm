import AppKit
import SwiftTerm

/// Configuration for NotchTerm, loaded from ~/.config/notchterm/config.json
struct Configuration: Codable {
    var font: FontConfig
    var terminal: TerminalConfig
    var theme: ThemeConfig
    var animation: AnimationConfig

    struct FontConfig: Codable {
        var family: String
        var size: CGFloat
        var weight: String

        static let `default` = FontConfig(
            family: "SF Mono",
            size: 13,
            weight: "regular"
        )
    }

    struct TerminalConfig: Codable {
        var width: CGFloat
        var heightBelowNotch: CGFloat

        static let `default` = TerminalConfig(
            width: 700,
            heightBelowNotch: 320
        )
    }

    struct ThemeConfig: Codable {
        var background: String
        var foreground: String
        var cursor: String
        var selectionBackground: String
        var selectionForeground: String
        var backgroundOpacity: CGFloat
        var backgroundBlurRadius: CGFloat

        // ANSI colors (0-15)
        var black: String
        var red: String
        var green: String
        var yellow: String
        var blue: String
        var magenta: String
        var cyan: String
        var white: String
        var brightBlack: String
        var brightRed: String
        var brightGreen: String
        var brightYellow: String
        var brightBlue: String
        var brightMagenta: String
        var brightCyan: String
        var brightWhite: String

        // Default: A clean dark theme inspired by popular terminal themes
        static let `default` = ThemeConfig(
            background: "#1a1b26",  // Dark blue-gray
            foreground: "#c0caf5",  // Soft blue-white
            cursor: "#c0caf5",
            selectionBackground: "#33467c",
            selectionForeground: "#c0caf5",
            backgroundOpacity: 0.9,
            backgroundBlurRadius: 5,

            // Normal colors
            black: "#15161e",
            red: "#f7768e",
            green: "#9ece6a",
            yellow: "#e0af68",
            blue: "#7aa2f7",
            magenta: "#bb9af7",
            cyan: "#7dcfff",
            white: "#a9b1d6",

            // Bright colors
            brightBlack: "#414868",
            brightRed: "#f7768e",
            brightGreen: "#9ece6a",
            brightYellow: "#e0af68",
            brightBlue: "#7aa2f7",
            brightMagenta: "#bb9af7",
            brightCyan: "#7dcfff",
            brightWhite: "#c0caf5"
        )
    }

    struct AnimationConfig: Codable {
        var duration: Double

        static let `default` = AnimationConfig(duration: 0.35)
    }

    static let `default` = Configuration(
        font: .default,
        terminal: .default,
        theme: .default,
        animation: .default
    )

    // MARK: - File Path

    static var configDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("notchterm")
    }

    static var configFile: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    // MARK: - Loading

    static func load() -> Configuration {
        let fileManager = FileManager.default

        // Create config directory if needed
        if !fileManager.fileExists(atPath: configDirectory.path) {
            try? fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }

        // Create default config if none exists
        if !fileManager.fileExists(atPath: configFile.path) {
            Configuration.default.save()
            return .default
        }

        // Load existing config
        do {
            let data = try Data(contentsOf: configFile)
            let decoder = JSONDecoder()
            return try decoder.decode(Configuration.self, from: data)
        } catch {
            print("Failed to load config: \(error). Using defaults.")
            return .default
        }
    }

    // MARK: - Saving

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(self)
            try data.write(to: Configuration.configFile)
        } catch {
            print("Failed to save config: \(error)")
        }
    }

    // MARK: - Font Resolution

    func resolvedFont() -> NSFont {
        let weight: NSFont.Weight
        switch font.weight.lowercased() {
        case "ultralight": weight = .ultraLight
        case "thin": weight = .thin
        case "light": weight = .light
        case "regular": weight = .regular
        case "medium": weight = .medium
        case "semibold": weight = .semibold
        case "bold": weight = .bold
        case "heavy": weight = .heavy
        case "black": weight = .black
        default: weight = .regular
        }

        // Try to load the specified font
        if let customFont = NSFont(name: font.family, size: font.size) {
            return customFont
        }

        // Try system monospace with the family name
        let descriptor = NSFontDescriptor(fontAttributes: [
            .family: font.family,
            .traits: [NSFontDescriptor.TraitKey.weight: weight],
        ])
        if let font = NSFont(descriptor: descriptor, size: font.size) {
            return font
        }

        // Fallback to system monospace
        return NSFont.monospacedSystemFont(ofSize: font.size, weight: weight)
    }

    // MARK: - Color Resolution

    func resolvedBackgroundColor() -> NSColor {
        NSColor(hex: theme.background) ?? .black
    }

    func resolvedForegroundColor() -> NSColor {
        NSColor(hex: theme.foreground) ?? .white
    }

    func resolvedCursorColor() -> NSColor {
        NSColor(hex: theme.cursor) ?? resolvedForegroundColor()
    }

    func resolvedSelectionBackgroundColor() -> NSColor {
        NSColor(hex: theme.selectionBackground) ?? NSColor.selectedTextBackgroundColor
    }

    func resolvedSelectionForegroundColor() -> NSColor {
        NSColor(hex: theme.selectionForeground) ?? NSColor.selectedTextColor
    }

    /// Returns the 16 ANSI colors as SwiftTerm Color array for installColors
    func resolvedAnsiColors() -> [SwiftTerm.Color] {
        [
            theme.black.toSwiftTermColor(),
            theme.red.toSwiftTermColor(),
            theme.green.toSwiftTermColor(),
            theme.yellow.toSwiftTermColor(),
            theme.blue.toSwiftTermColor(),
            theme.magenta.toSwiftTermColor(),
            theme.cyan.toSwiftTermColor(),
            theme.white.toSwiftTermColor(),
            theme.brightBlack.toSwiftTermColor(),
            theme.brightRed.toSwiftTermColor(),
            theme.brightGreen.toSwiftTermColor(),
            theme.brightYellow.toSwiftTermColor(),
            theme.brightBlue.toSwiftTermColor(),
            theme.brightMagenta.toSwiftTermColor(),
            theme.brightCyan.toSwiftTermColor(),
            theme.brightWhite.toSwiftTermColor(),
        ]
    }
}

// MARK: - NSColor Hex Extension

extension NSColor {
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        guard hexString.count == 6,
            let hexValue = UInt64(hexString, radix: 16)
        else {
            return nil
        }

        let r = CGFloat((hexValue >> 16) & 0xFF) / 255.0
        let g = CGFloat((hexValue >> 8) & 0xFF) / 255.0
        let b = CGFloat(hexValue & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// MARK: - String to SwiftTerm Color Extension

extension String {
    /// Convert a hex color string to SwiftTerm's Color class (16-bit RGB)
    func toSwiftTermColor() -> SwiftTerm.Color {
        var hexString = self.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        guard hexString.count == 6,
            let hexValue = UInt64(hexString, radix: 16)
        else {
            return SwiftTerm.Color(red: 0, green: 0, blue: 0)
        }

        // Convert 8-bit to 16-bit (multiply by 257 to scale 0-255 to 0-65535)
        let r = UInt16((hexValue >> 16) & 0xFF) * 257
        let g = UInt16((hexValue >> 8) & 0xFF) * 257
        let b = UInt16(hexValue & 0xFF) * 257

        return SwiftTerm.Color(red: r, green: g, blue: b)
    }
}
