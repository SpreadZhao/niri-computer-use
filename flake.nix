{
  description = "Audited Niri/Wayland computer-use runtime and modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
    in
    {
      overlays.default = final: _: {
        niri-computer-use-aiui = final.callPackage ./nix/aiui.nix { };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        rec {
          aiui = pkgs.callPackage ./nix/aiui.nix { };
          default = aiui;
        }
      );

      homeModules = rec {
        default = import ./nix/home-module.nix;
        niri-computer-use = default;
      };

      homeManagerModules = self.homeModules;

      nixosModules = rec {
        default = import ./nix/nixos-module.nix;
        niri-computer-use = default;
      };

      lib = import ./nix/lib.nix;
    };
}
