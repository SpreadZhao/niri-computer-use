# Niri Computer Use

Audited Niri/Wayland computer-use runtime for `spreadconfig`.

This project is installed as a Nix flake. It does not patch `spreadconfig`, Niri
KDL, Waybar JSONC, or any live system configuration.

## What The Flake Installs

- `packages.<system>.aiui`: the `aiui` runtime wrapped with Python and the
  command-line tools it uses.
- `homeManagerModules.default`: generic Home Manager module for non-spreadconfig
  users.
- `nixosModules.default`: enables `ydotoold` support and adds the configured
  user to the `ydotool` group.

The flake does not configure Niri hotkeys or Waybar UI. Those are local desktop
preferences and should be added in `spreadconfig`.

## Add The Flake To spreadconfig

In `~/workspaces/spreadconfig/flake.nix`, add an input:

```nix
niri-computer-use = {
  url = "github:SpreadZhao/niri-computer-use";
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

Then install it using the same one-file-per-feature style as the rest of
`spreadconfig`.

Create `modules/home/niri-computer-use.nix`:

```nix
{ inputs, pkgs, ... }:

let
  system = pkgs.stdenv.hostPlatform.system;
  niriComputerUse = inputs.niri-computer-use.packages.${system}.aiui;
in
{
  home.packages = [ niriComputerUse ];

  xdg.desktopEntries.aiui-control = {
    name = "AI Desktop Controls";
    comment = "Pause, stop, inspect, or reset Niri computer-use automation";
    exec = "${niriComputerUse}/bin/aiui menu --source launcher";
    icon = "preferences-system";
    categories = [
      "System"
      "Utility"
    ];
    terminal = false;
    type = "Application";
  };
}
```

Create `modules/nixos/niri-computer-use.nix`:

```nix
{ ... }:

{
  programs.ydotool = {
    enable = true;
    group = "ydotool";
  };

  users.users.spreadzhao.extraGroups = [ "ydotool" ];
}
```

Register the skill in `skills/sources.nix` using the existing `skillDirs`
mechanism:

```nix
niriComputerUseSkill = {
  niri-computer-use = {
    source = "${inputs.niri-computer-use}/overlay/skills/local/niri-computer-use";
    force = true;
  };
};
```

After this rebuild, the runtime command should exist in the Home Manager profile:

```text
aiui
```

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
Mod+Escape repeat=false hotkey-overlay-title="AI automation: emergency stop" { spawn-sh "aiui emergency-stop --source niri"; }
Mod+Ctrl+Escape repeat=false hotkey-overlay-title="AI automation: pause or resume" { spawn-sh "aiui toggle-pause --source niri"; }
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
    "exec": "aiui waybar",
    "return-type": "json",
    "interval": "once",
    "signal": 10,
    "on-click": "aiui menu --source waybar",
    "on-click-middle": "aiui toggle-pause --source waybar",
    "on-click-right": "aiui emergency-stop --source waybar",
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
AIUI="aiui"

"$AIUI" doctor
"$AIUI" session start --task 'Validate Niri computer use'
"$AIUI" observe
"$AIUI" launch \
  --reason 'Open WeChat for the current desktop task' \
  --risk medium \
  -- /home/spreadzhao/scripts/util/start_wechat.sh
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
- GUI application launches use `aiui launch -- ...` so long-running apps do not
  hold the runtime in `acting`.
- XWayland-only targets can be clicked with `aiui x11-click --window-name ...`
  using window-relative coordinates while still going through aiui policy.
- Privilege escalation and disk-management commands are denied by policy.
- Unknown CLI programs default to high risk.

This is still a soft operational boundary. An agent with unrestricted access to
the same user shell can bypass local wrapper policy. Strong isolation requires a
separate actuator account or broker.
