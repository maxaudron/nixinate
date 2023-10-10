{ config, lib, pkgs, ... }:

with lib;
{
  options.deploy = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Enable deployment of this configuration to a remote host.
      '';
    };

    endpoint = mkOption {
      type = types.string;
      description = ''
        IP Address to connect to machine with.
      '';
    };

    sshUser = mkOption {
      type = types.nullOr types.string;
      default = null;
      description = ''
        Override the user used for ssh and use the one
        specificed here instead of your local username.
      '';
    };

    hermetic = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Build the config with the nixos-rebuild command from
        your flakes nixpkgs, instead of the hosts nixpkgs.
      '';
    };

    buildOn = mkOption {
      type = types.enum [ "local" "remote" ];
      default = "remote";
      description = ''
        Build the config either on your local system or on the
        system it will be deployed to.
      '';
    };

    substituteOnTarget = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Pull packages from the nix caches directly on the deployment
        target, instead of pulling them locally and copying them to
        the target.
      '';
    };

    nixOptions = mkOption {
      type = types.list types.string;
      default = [ ];
      description = ''
        Extra CLI Flags to pass to nixos-rebuild.
      '';
    };
  };
}
