# Niri Computer Use

Audited Niri/Wayland computer-use runtime for `spreadconfig`.

This project is installed as a Nix flake. It does not patch `spreadconfig`, Niri
KDL, Waybar JSONC, or any live system configuration.

## What The Flake Installs

- `packages.<system>.aiui`: the `aiui` runtime wrapped with Python and the
  command-line tools it uses.
- `homeManagerModules.default`: installs the runtime command, the
  `niri-computer-use` skill, and the **AI Desktop Controls** launcher entry.
- `nixosModules.default`: enables `ydotoold` support and adds the configured
  user to the `ydotool` group.

The flake does not configure Niri hotkeys or Waybar UI. Those are local desktop
preferences and should be added in `spreadconfig`.

## Add The Flake To spreadconfig

In `~/workspaces/spreadconfig/flake.nix`, add an input:

```nix
niri-computer-use = {
  url = "github:SpreadZhao/niri-computer-use-spreadconfig-v2";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

For local development before pushing, use:

```nix
niri-computer-use = {
  url = "path:/home/spreadzhao/workspaces/niri-computer-use-spreadconfig-v2";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Then import the modules in the host construction.

Add the NixOS module to the `modules = [ ... ]` list passed to
`nixpkgs.lib.nixosSystem`:

```nix
inputs.niri-computer-use.nixosModules.default
```

Add the Home Manager module to `home-manager.users.spreadzhao.imports`:

```nix
inputs.niri-computer-use.homeManagerModules.default
```

Enable the modules:

```nix
{
  services.niri-computer-use = {
    enable = true;
    user = "spreadzhao";
  };

  home-manager.users.spreadzhao.programs.niri-computer-use = {
    enable = true;
    scriptsDir = "/home/spreadzhao/scripts";
    skillDirectories = [
      ".agents/skills"
      ".claude/skills"
      "workspaces/spreadconfig/.agents/skills"
      "workspaces/spreadconfig/.claude/skills"
    ];
  };
}
```

After this rebuild, the runtime command should exist at:

```text
~/scripts/aiui/aiui
```

The command is also installed as `aiui` in the Home Manager profile.

## Manual Niri Configuration

Add this top-level rule to any Niri `config.kdl` you want protected from
automation screenshots:

```kdl
window-rule {
    match app-id=r#"(?i)^(org\.keepassxc\.KeePassXC|org\.gnome\.World\.Secrets|com\.bitwarden\.desktop|1password)$"#
    block-out-from "screen-capture"
}
```

Add these inside the existing `binds { ... }` block:

```kdl
Mod+Escape repeat=false hotkey-overlay-title="AI automation: emergency stop" { spawn-sh "$SCRIPT_HOME/aiui/aiui emergency-stop --source niri"; }
Mod+Ctrl+Escape repeat=false hotkey-overlay-title="AI automation: pause or resume" { spawn-sh "$SCRIPT_HOME/aiui/aiui toggle-pause --source niri"; }
```

These bindings are optional but recommended. They give you a compositor-level
pause and emergency stop for agent desktop control.

## Manual Waybar Configuration

Add `custom/aiui` to your Waybar `modules-left` list:

```jsonc
"modules-left": [
    "group/niri-workspace-window",
    "custom/screen-record-time",
    "custom/aiui"
]
```

Add the module definition:

```jsonc
"custom/aiui": {
    "exec": "/home/spreadzhao/scripts/aiui/aiui waybar",
    "return-type": "json",
    "interval": "once",
    "signal": 10,
    "on-click": "/home/spreadzhao/scripts/aiui/aiui menu --source waybar",
    "on-click-middle": "/home/spreadzhao/scripts/aiui/aiui toggle-pause --source waybar",
    "on-click-right": "/home/spreadzhao/scripts/aiui/aiui emergency-stop --source waybar",
    "tooltip": true
}
```

Add CSS if you want the status states styled:

```css
#custom-aiui {
    background: @theme_background;
    padding-left: 7px;
    padding-right: 7px;
    color: @theme_bright_dark;
}

#custom-aiui.ready,
#custom-aiui.observing {
    color: @theme_blue;
}

#custom-aiui.acting {
    color: @theme_bright_yellow;
}

#custom-aiui.approval,
#custom-aiui.error {
    color: @theme_bright_red;
    border-top: 2px solid @theme_bright_red;
}

#custom-aiui.paused {
    color: @theme_yellow;
    border-top: 2px solid @theme_yellow;
}

#custom-aiui.stopped {
    color: @theme_bright_red;
    background: @theme_bright_background;
    border-top: 2px solid @theme_bright_red;
}
```

Waybar display states:

| Display | Meaning |
|---|---|
| `AI` | no active session |
| `AI·` | session ready |
| `AI◌` | observing |
| `AI▶` | executing an action |
| `AI?` | waiting for approval |
| `AIⅡ` | paused |
| `AI■` | emergency-stopped |
| `AI!` | runtime error |

## Rebuild

From `~/workspaces/spreadconfig`:

```bash
~/scripts/nix/sns_until switch
```

The NixOS module changes group membership, so log out of the graphical session
and log back in before testing pointer control through `ydotool`.

Restart Waybar after changing its config:

```bash
systemctl --user restart waybar.service
```

## Validate

```bash
AIUI="$HOME/scripts/aiui/aiui"

"$AIUI" doctor
"$AIUI" session start --task 'Validate Niri computer use'
"$AIUI" observe
"$AIUI" niri-action toggle-overview \
  --reason 'Validate a harmless Niri action' \
  --risk low
"$AIUI" observe
"$AIUI" session end --result 'validation completed'
```

Then test the user controls:

1. Start another session.
2. Middle-click the Waybar `AI` module; the next action should be blocked as paused.
3. Resume from the left-click control menu.
4. Right-click the module; the next action should be blocked by emergency stop.
5. Left-click and choose **Reset emergency stop**.

Do not run the first live validation on unsaved work or a sensitive window.

## Runtime Locations

```text
$XDG_RUNTIME_DIR/aiui/state.json       current state, mode 0600
$XDG_RUNTIME_DIR/aiui/screen-*.png     temporary screenshots, mode 0600
$XDG_STATE_HOME/aiui/audit.jsonl       persistent redacted audit events
```

## Safety Notes

- Every wrapper action checks the pause and emergency-stop latch.
- High-risk actions require exact, single-use user approval.
- Typed text is never written to the audit log; only length and SHA-256 are logged.
- The command runner uses argv arrays, not `shell=True`.
- Privilege escalation and disk-management commands are denied by policy.
- Unknown CLI programs default to high risk.

This is still a soft operational boundary. An agent with unrestricted access to
the same user shell can bypass local wrapper policy. Strong isolation requires a
separate actuator account or broker.
