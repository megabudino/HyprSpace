# Homebrew Tap for HyprSpace

This is the official Homebrew tap for [HyprSpace](https://github.com/BarutSRB/HyprSpace), a Hyprland-inspired tiling window manager for macOS.

## Installation

```bash
# Add the tap
brew tap barutsrb/hyprspace

# Install HyprSpace
brew install --cask hyprspace
```

## Updating

```bash
# Update Homebrew and the tap
brew update

# Upgrade HyprSpace
brew upgrade --cask hyprspace
```

## Uninstallation

```bash
brew uninstall --cask hyprspace
```

## Manual Installation

If you prefer to install without Homebrew, you can download the latest release directly from the [GitHub releases page](https://github.com/BarutSRB/HyprSpace/releases).

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permissions (will be requested on first launch)

## License

HyprSpace is licensed under the MIT License. See the main repository for details.

## Repository Setup Instructions

To set up this tap repository:

1. Create a new GitHub repository named `homebrew-hyprspace`
2. Copy the contents of this template directory to your new repository
3. Update the GitHub Actions workflow with your repository details
4. Configure the following secrets in your repository settings:
   - `GITHUB_TOKEN`: Personal access token with `repo` scope
   - `HYPRSPACE_REPO_TOKEN`: Token to access the main HyprSpace repository (optional)

The tap will automatically update when new releases are published to the main HyprSpace repository.