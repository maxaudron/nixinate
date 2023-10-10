# The importApply argument. Use this to reference things defined locally,
# as opposed to the flake where this is imported.
localFlake:

# Regular module arguments; self, inputs, etc all reference the final user flake,
# where this module was imported.
{ lib, config, self, inputs, ... }:
let
  lib = inputs.nixpkgs.lib;
  generateApps = import ./generate-apps.nix inputs.nixpkgs;
in
{
  flake = {
  };
  perSystem = { system, pkgs, ... }: {
    apps = generateApps pkgs self;
  };
}
