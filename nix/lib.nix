{
  waybarModule =
    aiuiPath:
    {
      exec = "${aiuiPath} waybar";
      return-type = "json";
      interval = "once";
      signal = 10;
      on-click = "${aiuiPath} menu --source waybar";
      on-click-middle = "${aiuiPath} toggle-pause --source waybar";
      on-click-right = "${aiuiPath} emergency-stop --source waybar";
      tooltip = true;
    };

  waybarCss = ''
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
  '';

  niriSensitiveWindowRule = ''
    window-rule {
        match app-id=r#"(?i)^(org\\.keepassxc\\.KeePassXC|org\\.gnome\\.World\\.Secrets|com\\.bitwarden\\.desktop|1password)$"#
        block-out-from "screen-capture"
    }
  '';

  niriBinds =
    aiuiPath:
    ''
        Mod+Escape repeat=false hotkey-overlay-title="AI automation: emergency stop" { spawn-sh "${aiuiPath} emergency-stop --source niri"; }
        Mod+Ctrl+Escape repeat=false hotkey-overlay-title="AI automation: pause or resume" { spawn-sh "${aiuiPath} toggle-pause --source niri"; }
    '';
}
