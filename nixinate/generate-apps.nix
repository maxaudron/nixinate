nixpkgs: pkgs: flake:

let
  machines = builtins.attrNames flake.nixosConfigurations;
  validMachines = nixpkgs.lib.remove ""
    (nixpkgs.lib.forEach machines
      (x: nixpkgs.lib.optionalString
        (flake.nixosConfigurations."${x}".config.deploy.enable) "${x}"));
  mkDeployScript = import ./make-deploy-script.nix { inherit nixpkgs pkgs flake; };
    rebuildActions = [ "switch" "boot" "test" "build" "dry-build" "dry-activate" "build-vm" "build-vm-with-bootloader" ];
in
nixpkgs.lib.genAttrs
  #   validMachines
  #   (x:
#  #     {
  #       type = "app";
  #       program = toString (mkDeployScript {
  #         machine = x;
  #         dryRun = false;
  #       });
  #     }
  #   )
  #   // nixpkgs.lib.genAttrs
  # (map (machineName: a + "-dry-run") validMachines)
# (builtins.concatMap (rebuildAction: (concatMap: machineName: (machineName + "-" + rebuildAction) validMachines) ) rebuildActions )
# map validMachines
 (nixpkgs.lib.concatMap (machine: map (action: machine + "_" + action) rebuildActions ) validMachines)
  (x:
  let
    parts = builtins.split "_" x;
    machineName = builtins.head parts;
    #ugly, but works. I really can't bother figuring out better ATM
    rebuildAction = builtins.toString (builtins.tail( builtins.tail parts));
  in
  {
    type = "app";
    program = toString (mkDeployScript {
      machine = machineName;
      rebuildAction = builtins.trace rebuildAction rebuildAction;
      # inherit rebuildAction;
    });
  }
  )
