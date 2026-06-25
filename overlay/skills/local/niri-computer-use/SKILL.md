---
name: niri-computer-use
description: Observe and operate SpreadZhao's live Niri/Wayland desktop through the audited ~/scripts/aiui/aiui control surface. Use when an agent must inspect screenshots and Niri IPC state, focus windows/workspaces, type with wtype, click with ydotool, run structured CLI tools, or pause for exact user approval before consequential desktop actions.
---

# Niri Computer Use

Use the repository-managed runtime at:

```bash
AIUI="aiui"
```

This skill controls the current Niri session. It also drives the `custom/aiui` Waybar module, fnott notifications, and the fuzzel approval/control menus.

## Non-negotiable rules

1. Start one explicit session before observing or acting:

   ```bash
   "$AIUI" session start --task 'Concise description of the user request'
   ```

2. For desktop control, never call raw `grim`, `wtype`, `ydotool`, or `niri msg action`. Use the `aiui` commands below so Waybar state, stop controls, approvals, and audit logging remain effective.
3. Observe immediately before every coordinate-based action. After one UI action, observe again before choosing the next action. Never click from a stale screenshot.
4. Prefer deterministic control in this order:

   ```text
   application CLI/API > read-only CLI > Niri IPC > keyboard > coordinate click
   ```

5. Mark every consequential action `--risk high`. This includes deleting or overwriting data, closing a window that may contain unsaved work, sending a message, submitting a form, publishing, purchasing, installing or removing software, changing system configuration, and pushing to a remote repository.
6. Never type, reveal, capture, or request passwords, passphrases, private keys, tokens, recovery codes, payment details, or one-time authentication codes. Ask the user to take over.
7. A `paused` or `stopped` result is final. Do not call `resume`, `reset-stop`, invoke lower-level input tools, or otherwise work around it. Only the user may re-enable controls through Waybar, the launcher entry, or the Niri key binding.
8. Do not use `observe --force-sensitive` unless the user has explicitly identified the protected window and explicitly authorized that exact screenshot.
9. End the session when the desktop task is complete or cannot continue:

   ```bash
   "$AIUI" session end --result 'completed'
   ```

## Standard loop

```bash
AIUI="aiui"

"$AIUI" doctor
"$AIUI" session start --task 'Open the requested settings page and inspect it'
"$AIUI" observe
# Inspect the returned screenshot and JSON state.
# Execute exactly one next action.
"$AIUI" observe
"$AIUI" session end --result 'completed'
```

`observe` returns a screenshot path plus `focused_window`, `windows`, `workspaces`, and `outputs`. Screenshots are temporary and retained only in `$XDG_RUNTIME_DIR/aiui`.

## Desktop actions

### Focus a known Niri window

```bash
"$AIUI" niri-action focus-window --id 123 \
  --reason 'Focus the editor selected from the current Niri window list' \
  --risk low
```

### Switch workspace or overview

```bash
"$AIUI" niri-action focus-workspace --index 2 \
  --reason 'Move to the workspace containing the browser' \
  --risk low

"$AIUI" niri-action toggle-overview \
  --reason 'Show the Niri overview for navigation' \
  --risk low
```

### Type text

Prefer stdin so shell quoting cannot alter the text:

```bash
printf '%s' 'hello' | "$AIUI" type --stdin \
  --reason 'Enter the user-provided text in the visible editor' \
  --risk medium
```

Do not type a terminal command with a trailing newline unless the command has already been classified and any required approval has been granted.

### Press a hotkey

```bash
"$AIUI" hotkey ctrl+l \
  --reason 'Focus the browser address field' \
  --risk medium
```

The runtime explicitly presses and releases every modifier.

### Launch a GUI app

Use `launch`, not `run`, for long-running GUI programs. `launch` starts the app
under the same state, approval, and audit controls, then returns immediately.

```bash
"$AIUI" launch \
  --reason 'Open WeChat for the current desktop task' \
  --risk medium \
  -- wechat
```

### Click a visible target

```bash
"$AIUI" click --x 1200 --y 700 --button left \
  --reason 'Click the visible Advanced button in the current fresh screenshot' \
  --risk medium
```

For buttons such as Delete, Send, Submit, Install, Apply, Publish, or Confirm, use `--risk high`. The runtime will show the exact action and a fingerprint in fnott/fuzzel before execution.

### Close a window

```bash
"$AIUI" niri-action close-window \
  --reason 'Close the completed preview window; this may discard unsaved state' \
  --risk high
```

## Structured command-line tools

Use the argv-based runner for commands that are part of the desktop task. It does not invoke a shell, so pipes, redirections, command substitution, and `sh -c` are unavailable.

```bash
"$AIUI" run --reason 'List files before choosing one in the file manager' -- ls -la
"$AIUI" run --cwd "$HOME/workspaces/project" \
  --reason 'Inspect repository state before editing' -- git status --short
```

The runtime classifies the argv. Privilege escalation and disk-management tools are denied. State-changing, network-publishing, Nix, Git, process-control, and file-mutating commands require approval or are blocked according to policy.

## User-visible controls

The Waybar module is always visible:

- Left click: open the AI desktop control menu.
- Middle click: pause or resume.
- Right click: emergency stop.

Niri bindings installed by this integration:

```text
Mod+Escape       emergency stop
Mod+Ctrl+Escape  pause/resume
```

The fuzzel launcher also contains **AI Desktop Controls**.

The emergency stop latches in `$XDG_RUNTIME_DIR/aiui/state.json`. Every later wrapper action is rejected until the user interactively resets it.

## Status codes

- `idle`: no active automation session.
- `ready`: session active and waiting for the next action.
- `observing`: screenshot/Niri state is being captured.
- `acting`: input, Niri action, or structured CLI command is executing.
- `approval`: an exact high-risk action is waiting for the user.
- `paused`: actions are blocked until the user resumes.
- `stopped`: emergency-stop latch; actions are blocked until interactive user reset.
- `error`: the last operation failed; inspect the JSON error and audit log.

Read `references/SAFETY.md` before changing policy or adding new actuator commands.
