{ hostSettings, ... }:
{
  imports = [
    ./hardware.nix
    ../../modules/base.nix
    ../../modules/access.nix
    ../../modules/storage.nix
    ../../modules/persistence.nix
    ../../modules/secrets.nix
    ../../modules/tailscale.nix
  ];

  nixpkgs.hostPlatform = hostSettings.system;
  networking.hostName = "arbour-haus";

  # Installation compatibility version, not the nixpkgs update target.
  system.stateVersion = "26.05";
}
