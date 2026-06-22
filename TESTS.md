# Validation

Current local checks:

- Python syntax for `aiui` and `tools/verify.py`.
- Policy JSON parsing and schema version.
- Skill frontmatter and safety documentation presence.
- Runtime state transitions without UI actuation: `idle -> ready -> stopped`.
- Waybar status JSON generation.
- Pause/emergency-stop policy gate behavior through runtime state.
- Hotkey parsing.
- Structured command classification for `git push` and `sudo`.
- Verification that the legacy patch installer files are absent.

Nix checks to run on a machine with Nix daemon access:

```bash
./verify.sh --nix
```

Live desktop checks to run after installing through `spreadconfig` and adding
the manual Niri/Waybar snippets are listed in `README.md`.

Not covered by static validation:

- Live Niri IPC.
- `grim` screenshot capture.
- `wtype` keyboard input.
- `ydotool` pointer input.
- `fnott`, `fuzzel`, and Waybar rendering.
