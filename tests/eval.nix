{ mkHost, hostNames }:
let
  settings = import ./host-settings.nix;
  config = (mkHost settings).config;
  unconfigured =
    (mkHost (
      settings
      // {
        disk = "/dev/disk/by-id/REPLACE-ME";
        adminAuthorizedKeys = [ ];
      }
    )).config;
  failedAssertions = builtins.filter (a: !a.assertion) unconfigured.assertions;
  failsWith =
    prefix: builtins.any (a: builtins.match "${prefix}.*" a.message != null) failedAssertions;
  persistence = config.environment.persistence."/persist";
  persistentFiles = map (file: file.file) persistence.files;
  persistentDirectories = map (dir: dir.directory) persistence.directories;
  tailscaleState = builtins.filter (
    dir: dir.directory == "/var/lib/tailscale"
  ) persistence.directories;
in
assert hostNames == [ "arbour-haus" ];
assert failsWith "Set disk in host-settings.nix";
assert failsWith "Set adminAuthorizedKeys in host-settings.nix";
assert config.networking.hostName == "arbour-haus";
assert config.nixpkgs.hostPlatform.system == "x86_64-linux";
assert config.system.stateVersion == "26.05";
assert config.fileSystems."/".fsType == "tmpfs";
assert builtins.elem "size=25%" config.fileSystems."/".options;
assert config.fileSystems."/nix".fsType == "btrfs";
assert config.fileSystems."/persist".fsType == "btrfs";
assert config.fileSystems."/nix".neededForBoot;
assert config.fileSystems."/persist".neededForBoot;
assert builtins.elem "/etc/nixos" persistentDirectories;
assert builtins.elem "/var/lib/nixos" persistentDirectories;
assert builtins.elem "/etc/machine-id" persistentFiles;
assert builtins.all (
  key: builtins.elem key.path persistentFiles && builtins.elem "${key.path}.pub" persistentFiles
) config.services.openssh.hostKeys;
assert builtins.all (
  dir:
  !(builtins.elem dir [
    "/home"
    "/root"
    "/etc"
    "/var"
  ])
) persistentDirectories;
assert config.fileSystems."/boot".fsType == "vfat";
assert !config.users.mutableUsers;
assert config.services.openssh.enable;
assert config.services.openssh.settings.PasswordAuthentication == false;
assert config.services.openssh.settings.KbdInteractiveAuthentication == false;
assert config.services.openssh.settings.PermitRootLogin == "no";
assert config.users.users.admin.openssh.authorizedKeys.keys == settings.adminAuthorizedKeys;
assert !config.security.sudo.wheelNeedsPassword;
assert config.networking.firewall.enable;
assert builtins.elem 22 config.networking.firewall.allowedTCPPorts;
assert !(builtins.elem 8123 config.networking.firewall.allowedTCPPorts);
assert config.services.tailscale.enable;
assert config.services.tailscale.authKeyFile == null;
assert config.services.tailscale.extraSetFlags == [ "--ssh=false" ];
assert config.services.tailscale.disableTaildrop;
assert config.services.tailscale.useRoutingFeatures == "none";
assert builtins.elem config.services.tailscale.port config.networking.firewall.allowedUDPPorts;
assert !(builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces);
assert builtins.length tailscaleState == 1;
assert (builtins.head tailscaleState).user == "root";
assert (builtins.head tailscaleState).group == "root";
assert (builtins.head tailscaleState).mode == "0700";
assert config.sops.age.sshKeyPaths == [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
assert builtins.elem "/etc/ssh/ssh_host_ed25519_key" persistentFiles;
assert config.sops.secrets == { };
assert !config.services.home-assistant.enable;
assert !config.nix.channel.enable;
assert config.nix.nixPath == [ ];
assert builtins.elem "flakes" config.nix.settings.experimental-features;
assert config.nix.settings.flake-registry == "";
{
  # Force full NixOS assertions/derivation evaluation without building Linux.
  toplevel = config.system.build.toplevel.drvPath;
  disko = config.system.build.diskoScript.drvPath;
}
