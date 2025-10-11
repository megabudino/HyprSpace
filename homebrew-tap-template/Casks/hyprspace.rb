cask "hyprspace" do
  version "0.0.0-SNAPSHOT"
  sha256 :no_check # Will be updated by CI

  url "https://github.com/BarutSRB/HyprSpace/releases/download/v#{version}/HyprSpace-v#{version}.zip"
  name "HyprSpace"
  desc "Hyprland-inspired tiling window manager for macOS"
  homepage "https://github.com/BarutSRB/HyprSpace"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :ventura"

  app "HyprSpace.app"
  binary "bin/hyprspace"

  # Install man pages
  manpage "manpage/hyprspace.1"
  manpage "manpage/hyprspace-bind.1"
  manpage "manpage/hyprspace-close.1"
  manpage "manpage/hyprspace-config.1"
  manpage "manpage/hyprspace-flatten-workspace-tree.1"
  manpage "manpage/hyprspace-focus.1"
  manpage "manpage/hyprspace-focus-monitor.1"
  manpage "manpage/hyprspace-fullscreen.1"
  manpage "manpage/hyprspace-join-with.1"
  manpage "manpage/hyprspace-layout.1"
  manpage "manpage/hyprspace-list-apps.1"
  manpage "manpage/hyprspace-list-exec.1"
  manpage "manpage/hyprspace-list-monitors.1"
  manpage "manpage/hyprspace-list-windows.1"
  manpage "manpage/hyprspace-list-workspaces.1"
  manpage "manpage/hyprspace-macos-native-fullscreen.1"
  manpage "manpage/hyprspace-macos-native-minimize.1"
  manpage "manpage/hyprspace-mode.1"
  manpage "manpage/hyprspace-move.1"
  manpage "manpage/hyprspace-move-node-to-monitor.1"
  manpage "manpage/hyprspace-move-node-to-workspace.1"
  manpage "manpage/hyprspace-move-workspace-to-monitor.1"
  manpage "manpage/hyprspace-query.1"
  manpage "manpage/hyprspace-reload-config.1"
  manpage "manpage/hyprspace-resize.1"
  manpage "manpage/hyprspace-split.1"
  manpage "manpage/hyprspace-trigger-binding.1"
  manpage "manpage/hyprspace-workspace.1"
  manpage "manpage/hyprspace-workspace-back-and-forth.1"

  # Install shell completions
  bash_completion "shell-completion/bash/hyprspace"
  zsh_completion "shell-completion/zsh/_hyprspace"
  fish_completion "shell-completion/fish/hyprspace.fish"

  postflight do
    # Remove quarantine attribute
    system_command "/usr/bin/xattr",
                   args: ["-cr", "#{staged_path}/HyprSpace.app"],
                   sudo: false
  end

  uninstall quit: "barut.hyprspace",
            delete: [
              "~/.hyprspace.toml",
              "~/.hyprspace-debug.toml",
            ]

  zap trash: [
    "~/Library/Preferences/barut.hyprspace.plist",
    "~/Library/LaunchAgents/barut.hyprspace.plist",
  ]

  caveats <<~EOS
    HyprSpace requires accessibility permissions to manage windows.
    You will be prompted to grant these permissions on first launch.

    To start HyprSpace automatically at login, run:
      hyprspace service start

    Configuration file will be created at ~/.hyprspace.toml on first run.
  EOS
end