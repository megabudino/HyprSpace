<img src="./resources/Assets.xcassets/AppIcon.appiconset/icon.png" width="128" height="128" align="right">

# HyprSpace

**A Hyprland-inspired tiling window manager for macOS**

HyprSpace brings the powerful Hyprland tiling window manager experience to macOS, featuring a beautiful workspace bar that seamlessly blends with the macOS aesthetic while remaining unobtrusive, useful, and fully interactive with mouse support.

This project is a heavily modified fork of [AeroSpace](https://github.com/nikitabobko/AeroSpace) by nikitabobko, with additional components from [Barik](https://github.com/mocki-toki/barik) by mocki-toki.

## 🎯 Project Goals

- **Hyprland Experience on macOS**: Get as close as possible to the Hyprland tiling window manager experience while respecting macOS conventions
- **Beautiful Workspace Bar**: The best looking workspace bar that blends naturally into the macOS design language
- **Unobtrusive Yet Powerful**: Stay out of your way during regular use while providing powerful window management when needed
- **Mouse-Friendly**: Full mouse interactivity alongside keyboard-driven workflows
- **macOS Integration**: Seamless integration with native macOS features where it makes sense

## ✨ Key Features

- **Dwindle Layout**: Binary tree-based tiling layout system inspired by Hyprland
- **Fast Workspace Switching**: Instant workspace transitions without animations
- **Virtual Workspaces**: Custom workspace implementation that bypasses macOS Spaces limitations
- **Tree-Based Window Management**: Hierarchical window organization for complex layouts
- **Multi-Monitor Support**: Proper i3-like multi-monitor paradigm
- **Plain Text Configuration**: TOML-based config files (dotfiles friendly)
- **CLI First**: Complete command-line interface with man pages and shell completion
- **No SIP Required**: Works without disabling System Integrity Protection

## 📦 Installation

Install via [Homebrew](https://brew.sh/) to get automatic updates (Recommended):

```bash
brew install --cask barutsrb/tap/hyprspace
```

For multi-monitor setups, ensure monitors are [properly arranged](https://barutsrb.github.io/HyprSpace/guide#proper-monitor-arrangement).

Other installation options: https://barutsrb.github.io/HyprSpace/guide#installation

> [!NOTE]
> HyprSpace is not [notarized](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution) by Apple. The Homebrew installation automatically handles the quarantine attribute to ensure smooth operation.

## 📚 Documentation

- [HyprSpace Guide](https://barutsrb.github.io/HyprSpace/guide) - Getting started and configuration
- [Commands Reference](https://barutsrb.github.io/HyprSpace/commands) - Complete command documentation
- [Goodies & Tips](https://barutsrb.github.io/HyprSpace/goodies) - Advanced features and customizations

### Quick Start

1. Install HyprSpace via Homebrew
2. Grant Accessibility permissions when prompted
3. Copy the default configuration:
   ```bash
   cp /opt/homebrew/Cellar/hyprspace/*/docs/config-examples/default-config.toml ~/.hyprspace.toml
   ```
4. Start using HyprSpace with the default keybindings (Alt-based, similar to i3/Hyprland)

## 🛠️ Configuration

HyprSpace uses a TOML configuration file located at `~/.hyprspace.toml`. The configuration supports:

- Custom keybindings with multiple modes
- Workspace-to-monitor assignments
- Gap configurations (inner and outer)
- Window detection callbacks
- Layout preferences
- Integration with external tools

Example configuration snippet:
```toml
# Dwindle is the primary layout
default-root-container-layout = 'dwindle'

[gaps]
inner.horizontal = 14
inner.vertical = 14
outer.left = 8
outer.bottom = 8
outer.top = 8
outer.right = 8

[mode.main.binding]
alt-h = 'focus left'
alt-j = 'focus down'
alt-k = 'focus up'
alt-l = 'focus right'
```

## 🤝 Community & Contributing

HyprSpace uses GitHub Discussions for community interaction. Please read [CONTRIBUTING.md](./CONTRIBUTING.md) before creating issues.

### Discussion Channels

- [General Discussions](https://github.com/barutsrb/HyprSpace/discussions)
- [Feature Ideas](https://github.com/barutsrb/HyprSpace/discussions/categories/feature-ideas)
- [Bug Reports](https://github.com/barutsrb/HyprSpace/discussions/categories/potential-bugs)
- [Q&A](https://github.com/barutsrb/HyprSpace/discussions/categories/questions-and-answers)

## 🚀 Development

### Prerequisites

- Swift 6.1.2+ (managed via swiftly)
- Xcode (for release builds)
- macOS 13.0+

### Building from Source

```bash
# Clone the repository
git clone https://github.com/barutsrb/HyprSpace.git
cd HyprSpace

# Install dependencies
./script/install-dep.sh

# Build debug version
./build-debug.sh

# Run tests
./run-tests.sh

# Format code
./format.sh
```

For detailed development instructions, see [dev-docs/development.md](./dev-docs/development.md).

## 🙏 Credits & Acknowledgments

HyprSpace stands on the shoulders of giants:

- **[AeroSpace](https://github.com/nikitabobko/AeroSpace)** by [nikitabobko](https://github.com/nikitabobko) - The foundational tiling window manager this project is based on
- **[Barik](https://github.com/mocki-toki/barik)** by [mocki-toki](https://github.com/mocki-toki) - Additional components and inspiration for the workspace bar

Special thanks to the Hyprland community for inspiration and the macOS window management community for continued support and feedback.

## 📋 Project Status

HyprSpace is in active development. While stable for daily use, expect improvements and potential breaking changes as we work towards version 1.0.

### Roadmap to 1.0

- [ ] Immutable tree data structure for improved stability
- [ ] Enhanced shell-like command combinators
- [ ] Better integration with macOS native features
- [ ] Performance optimizations for large window counts
- [ ] Sticky windows support

## 💡 Tips & Tricks

Enable window dragging from anywhere (not just title bar):
```bash
defaults write -g NSWindowShouldDragOnGesture -bool true
```

Now hold `Ctrl+Cmd` and drag any part of a window to move it.

## 📄 License

HyprSpace is released under the MIT License. See [LICENSE](./LICENSE) for details.

## 🔗 Related Projects

- [Hyprland](https://hyprland.org/) - The Wayland compositor that inspired this project
- [Amethyst](https://github.com/ianyh/Amethyst) - Automatic tiling window manager for macOS
- [yabai](https://github.com/koekeishiya/yabai) - A tiling window manager for macOS based on binary space partitioning

---

*HyprSpace - Bringing the Hyprland experience to macOS* 🚀