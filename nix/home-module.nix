{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.niri-computer-use;
  defaultPackage = pkgs.callPackage ./aiui.nix { };
  skillSource = ../overlay/skills/local/niri-computer-use;

  toHomeTarget =
    path:
    let
      homePrefix = "${config.home.homeDirectory}/";
    in
    if lib.hasPrefix "/" path then
      if lib.hasPrefix homePrefix path then
        lib.removePrefix homePrefix path
      else
        throw "programs.niri-computer-use path '${path}' must be relative to $HOME or inside ${config.home.homeDirectory}"
    else
      path;

  scriptTarget = "${toHomeTarget cfg.scriptsDir}/aiui/aiui";
  aiuiPath = if cfg.installScriptLink then "${cfg.scriptsDir}/aiui/aiui" else "${cfg.package}/bin/aiui";

  skillFiles = builtins.listToAttrs (
    map (dir: {
      name = "${toHomeTarget dir}/niri-computer-use";
      value = {
        source = skillSource;
        force = cfg.forceSkillLinks;
      };
    }) cfg.skillDirectories
  );
in
{
  options.programs.niri-computer-use = {
    enable = lib.mkEnableOption "the audited Niri computer-use runtime";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "pkgs.callPackage ./nix/aiui.nix { }";
      description = "Package providing the aiui command.";
    };

    scriptsDir = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/scripts";
      description = "Directory where the compatibility aiui script link is installed.";
    };

    installScriptLink = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to install scriptsDir/aiui/aiui for existing Niri and Waybar config.";
    };

    skillDirectories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        ".agents/skills"
        ".claude/skills"
      ];
      description = "Skill directories, relative to $HOME, where niri-computer-use is linked.";
    };

    forceSkillLinks = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Replace an existing niri-computer-use skill target managed by Home Manager.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file =
      (lib.optionalAttrs cfg.installScriptLink {
        ${scriptTarget}.source = "${cfg.package}/bin/aiui";
      })
      // skillFiles;

    xdg.desktopEntries.aiui-control = {
      name = "AI Desktop Controls";
      comment = "Pause, stop, inspect, or reset Niri computer-use automation";
      exec = "${aiuiPath} menu --source launcher";
      icon = "preferences-system";
      terminal = false;
      type = "Application";
      categories = [
        "System"
        "Utility"
      ];
    };
  };
}
