nixpkgs: pkgs: flake:

let
  machines = builtins.attrNames flake.nixosConfigurations;
  validMachines = nixpkgs.lib.remove ""
    (nixpkgs.lib.forEach machines
      (x: nixpkgs.lib.optionalString
        (flake.nixosConfigurations."${x}".config.deploy.enable) "${x}"));
  mkDeployScript = import ./make-deploy-script.nix { inherit nixpkgs pkgs flake; };
in
nixpkgs.lib.genAttrs
  validMachines
  (x:
    {
      type = "app";
      program = toString (mkDeployScript {
        machine = x;
        dryRun = false;
      });
    }
  )
  // nixpkgs.lib.genAttrs
  (map (a: a + "-dry-run") validMachines)
  (x:
    {
      type = "app";
      program = toString (mkDeployScript {
        machine = nixpkgs.lib.removeSuffix "-dry-run" x;
        dryRun = true;
      });
    }
  )
  // nixpkgs.lib.genAttrs
  (map (a: a + "-boot") validMachines)
  (x:
    {
      type = "app";
      program = toString (mkDeployScript {
        machine = nixpkgs.lib.removeSuffix "-boot" x;
        boot = true;
      });
    }
  )
