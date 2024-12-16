{ nixpkgs, pkgs, flake, ... }:
{ machine, dryRun }:
let
  inherit (builtins) abort;
  inherit (pkgs.lib) getExe optionalString concatStringsSep;

  nix = "${getExe pkgs.nix}";
  nixos-rebuild = "${getExe pkgs.nixos-rebuild}";
  openssh = "${getExe pkgs.openssh}";
  flock = "${getExe pkgs.flock}";

  n = flake.nixosConfigurations.${machine}.config.deploy;
  hermetic = n.hermetic;
  user = n.sshUser != null;
  conn = if user then "${n.sshUser}@${n.host}" else "${n.host}";
  where = n.buildOn or "remote";
  remote = if where == "remote" then true else if where == "local" then false else abort "_module.args.nixinate.buildOn is not set to a valid value of 'local' or 'remote'";
  substituteOnTarget = n.substituteOnTarget or false;
  switch = if dryRun then "dry-activate" else "switch";
  nixOptions = concatStringsSep " " (n.nixOptions or [ ]);

  script =
    ''
      set -e
      echo "🚀 Deploying nixosConfigurations.${machine} from ${flake}"
      echo "👤 SSH User: ${if user then n.sshUser else "$(whoami)"}"
      echo "🌐 SSH Host: ${n.host}"
    '' + (if remote then ''
      echo "🚀 Sending flake to ${machine} via nix copy:"
      ( set -x; ${nix} ${nixOptions} copy ${flake} --to ssh://${conn} )
    '' + (if hermetic then ''
      echo "🤞 Activating configuration hermetically on ${machine} via ssh:"
      ( set -x; ${nix} ${nixOptions} copy --derivation ${nixos-rebuild} ${flock} --to ssh://${conn} )
      ( set -x; ${openssh} -t ${conn} "sudo nix-store --realise ${nixos-rebuild} ${flock} && sudo ${flock} -w 60 /dev/shm/nixinate-${machine} ${nixos-rebuild} ${nixOptions} ${switch} --flake ${flake}#${machine}" )
    '' else ''
      echo "🤞 Activating configuration non-hermetically on ${machine} via ssh:"
      ( set -x; ${openssh} -t ${conn} "sudo flock -w 60 /dev/shm/nixinate-${machine} nixos-rebuild ${nixOptions} ${switch} --flake ${flake}#${machine}" )
    '')
    else ''
      echo "🔨 Building system closure locally, copying it to remote store and activating it:"
      ( set -x; NIX_SSHOPTS="-t" ${flock} -w 60 /dev/shm/nixinate-${machine} ${nixos-rebuild} ${nixOptions} ${switch} --flake ${flake}#${machine} --target-host ${conn} --use-remote-sudo ${optionalString substituteOnTarget "-s"} )

    '');
in
pkgs.writeShellScript "deploy-${machine}.sh" script
