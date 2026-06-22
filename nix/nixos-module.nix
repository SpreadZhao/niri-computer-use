{ config, lib, ... }:

let
  cfg = config.services.niri-computer-use;
in
{
  options.services.niri-computer-use = {
    enable = lib.mkEnableOption "system support for the Niri computer-use runtime";

    user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "spreadzhao";
      description = "User added to the ydotool group. Set to null to skip user group management.";
    };

    enableYdotool = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the upstream programs.ydotool service.";
    };

    ydotoolGroup = lib.mkOption {
      type = lib.types.str;
      default = "ydotool";
      description = "Group allowed to use the ydotool daemon socket.";
    };
  };

  config = lib.mkIf cfg.enable (
    {
      programs.ydotool = lib.mkIf cfg.enableYdotool {
        enable = true;
        group = cfg.ydotoolGroup;
      };
    }
    // lib.optionalAttrs (cfg.user != null) {
      users.users.${cfg.user}.extraGroups = [ cfg.ydotoolGroup ];
    }
  );
}
