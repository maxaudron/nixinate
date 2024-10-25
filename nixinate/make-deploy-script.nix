{ nixpkgs, pkgs, flake, ... }:
{ machine, rebuildAction }:
let
  inherit (builtins) abort hasAttr;
  inherit (pkgs.lib) getExe optionalString concatStringsSep;

  nix = "${getExe pkgs.nix}";
  nixos-rebuild = "${getExe pkgs.nixos-rebuild}";
  openssh = "${getExe pkgs.openssh}";
  flock = "${getExe pkgs.flock}";

  rev = flake.rev or flake.dirtyRev or pkgs.lib.fakeSha1;
  # forceRev = if (hasAttr "rev" flake) then flake.rev 
  #           else if (hasAttr "dirtyRev" flake) then (builtins.head (builtins.split "-dirty"))
  #           else "";
#  https://github.com/NixOS/nix/blob/0363dbf2b956674d95b8597d2fedd20fc2b529df/src/libfetchers/path.cc#L45
  targetFlake = "'${flake}?rev=${rev}"
            # + optionalString (hasAttr "rev" flake) "&rev=${flake.rev}"
            + optionalString (hasAttr "revCount" flake) "&revCount=${toString flake.revCount}"
            + optionalString (hasAttr "lastModified" flake) "&lastModified=${toString flake.lastModified}"
            + optionalString (hasAttr "narHash" flake) "&narHash=${flake.narHash}"
            + "'"
            ;
  # targetFlake = if rev == "unknown" then "${flake}" else "'path:${flake}?rev=${rev}'";
  n = flake.nixosConfigurations.${machine}.config.deploy;
  hermetic = n.hermetic;
  archiveFlake = n.archiveFlake;
  user = n.sshUser != null;
  conn = if user then "${n.sshUser}@${n.host}" else "${n.host}";
  where = n.buildOn or "remote";
  remote = if where == "remote" then true else if where == "local" then false else abort "_module.args.nixinate.buildOn is not set to a valid value of 'local' or 'remote'";
  substituteOnTarget = n.substituteOnTarget or false;
  # switch = if dryRun then "dry-activate" else "switch";
  nixOptions = concatStringsSep " " (n.nixOptions or [ ]);

  script =
    ''
      set -e
      echo "🚀 Deploying nixosConfigurations.${machine} from ${flake}"
      echo "📌 Flake revision: ${rev}"
      echo "👤 SSH User: ${if user then n.sshUser else "$(whoami)"}"
      echo "🌐 SSH Host: ${n.host}"
    ''
    + (if remote then
      (
          (if archiveFlake then 
             '' 
                echo "🚀 Sending flake and its inputs to ${machine} via nix flake archive:"
                ( set -x; ${nix} ${nixOptions} flake archive ${flake} --to ssh://${conn} )
             ''
             else
             ''
                echo "🚀 Sending flake to ${machine} via nix copy:"
                ( set -x; ${nix} ${nixOptions} copy ${flake} --to ssh://${conn} )
             ''
          )
          + (if hermetic then 
            ''
                echo "🤞 Activating configuration hermetically on ${machine} via ssh:"
                ( set -x; ${nix} ${nixOptions} copy --derivation ${nixos-rebuild} ${flock} --to ssh://${conn} )
                ( set -x; ${openssh} -t ${conn} "sudo nix-store --realise ${nixos-rebuild} ${flock} && sudo ${flock} -w 60 /dev/shm/nixinate-${machine} ${nixos-rebuild} ${nixOptions} ${rebuildAction} --flake ${targetFlake}#${machine}" )
            '' else
            ''
                echo "🤞 Activating configuration non-hermetically on ${machine} via ssh:"
                ( set -x; ${openssh} -t ${conn} "sudo flock -w 60 /dev/shm/nixinate-${machine} nixos-rebuild ${nixOptions} ${rebuildAction} --flake ${targetFlake}#${machine}" )
            '')
      )
    else ''
      echo "🔨 Building system closure locally, copying it to remote store and activating it:"
      ( set -x; NIX_SSHOPTS="-t" ${flock} -w 60 /dev/shm/nixinate-${machine} ${nixos-rebuild} ${nixOptions} ${rebuildAction} --flake ${targetFlake}#${machine} --target-host ${conn} --use-remote-sudo ${optionalString substituteOnTarget "-s"} )

    '');
in
pkgs.writeScript "deploy-${machine}.sh" script
