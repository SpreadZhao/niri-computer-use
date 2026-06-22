# Changes in v2.1.0

- Converted the project to a Nix flake with package, NixOS module, Home Manager
  module, overlay, and reusable config snippets.
- Removed the automatic `spreadconfig` patch installer. The project no longer
  edits Niri KDL, Waybar JSONC/CSS, skill registries, or host files.
- The Home Manager module installs the wrapped `aiui` command, a compatibility
  link at `~/scripts/aiui/aiui`, the local `niri-computer-use` skill, and the
  launcher desktop entry.
- The NixOS module enables `programs.ydotool` and adds the configured user to
  the `ydotool` group.
- README now documents the manual Niri and Waybar snippets required to expose
  pause, emergency stop, and the Waybar status module.

# Runtime Features

- Uses exact action-bound, single-use approval fingerprints for high-risk
  operations.
- Maintains private runtime screenshots and a persistent redacted audit log.
- Uses argv-only command execution instead of `shell=True`.
- Denies privilege escalation and disk-management commands by policy.
- Releases every wtype modifier explicitly after key release.
- Uses `niri msg action focus-window --id` for focused-window control.
