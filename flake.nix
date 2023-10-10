{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, flake-parts-lib, ... }:
      let
        inherit (flake-parts-lib) importApply;
        flakeModules.default = importApply ./nixinate { inherit withSystem; };
        nixosModules.default = import ./nixinate/module.nix;
      in
      {
        flake = {
          inherit flakeModules;
          flakeModule = flakeModules.default;

          inherit nixosModules;
          nixosModule = nixosModules.default;
        };
        systems = [
          "x86_64-linux"
          "x86_64-darwin"
          "aarch64-linux"
          "aarch64-darwin"
        ];
        perSystem = { config, ... }: { };
      });
}
