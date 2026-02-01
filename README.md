# NotchTerm

A dropdown terminal that lives in your MacBook's notch. Press a hotkey to summon it, press again to dismiss.

## Features

- **Notch integration** - Terminal drops down from the notch area with a smooth zoom animation
- **Global hotkey** - Toggle with `Ctrl+`` from anywhere
- **Click to toggle** - Hover over the notch and click to show/hide
- **Click outside to dismiss** - Terminal hides when you click elsewhere
- **tmux session** - Automatically creates or attaches to a persistent `NotchTerm` session
- **Customizable** - Configure fonts, colors, opacity, and blur

## Installation

### Build from source

Requires macOS 12+ and Xcode.

```bash
git clone https://github.com/skywardpixel/NotchTerm.git
cd NotchTerm
swift build -c release
cp .build/release/NotchTerm /usr/local/bin/
```

### Run

```bash
NotchTerm
```

The app runs in the menu bar (no dock icon). Look for the terminal icon in your menu bar.

## Configuration

NotchTerm looks for a config file at `~/.config/notchterm/config.json`. If it doesn't exist, defaults are used.

Example configuration:

```json
{
  "font": {
    "family": "SF Mono",
    "size": 13,
    "weight": "regular"
  },
  "terminal": {
    "width": 800,
    "heightBelowNotch": 400
  },
  "theme": {
    "background": "#1a1b26",
    "foreground": "#c0caf5",
    "backgroundOpacity": 0.9,
    "backgroundBlurRadius": 5,
    "black": "#15161e",
    "red": "#f7768e",
    "green": "#9ece6a",
    "yellow": "#e0af68",
    "blue": "#7aa2f7",
    "magenta": "#bb9af7",
    "cyan": "#7dcfff",
    "white": "#a9b1d6",
    "brightBlack": "#414868",
    "brightRed": "#f7768e",
    "brightGreen": "#9ece6a",
    "brightYellow": "#e0af68",
    "brightBlue": "#7aa2f7",
    "brightMagenta": "#bb9af7",
    "brightCyan": "#7dcfff",
    "brightWhite": "#c0caf5",
    "selectionBackground": "#33467c"
  },
  "animation": {
    "duration": 0.25
  }
}
```

## Requirements

- macOS 12.0+
- tmux (for session persistence)

## License

MIT
