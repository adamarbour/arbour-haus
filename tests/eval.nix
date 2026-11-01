let
  settings = import ./host-settings.nix;
  project = import ../. { hostSettings = settings; };
  config = project.nixosConfigurations.arbour-haus.config;
  # Test missing installation settings independently of the operator's real file.
  unconfigured =
    (import ../. {
      hostSettings = settings // {
        disk = "/dev/disk/by-id/REPLACE-ME";
        adminAuthorizedKeys = [ ];
      };
    }).nixosConfigurations.arbour-haus.config;
  failedAssertions = builtins.filter (a: !a.assertion) unconfigured.assertions;
  persistence = config.environment.persistence."/persist";
  persistentFiles = map (file: file.file) persistence.files;
  persistentDirectories = map (dir: dir.directory) persistence.directories;
in
assert builtins.attrNames project.nixosConfigurations == [ "arbour-haus" ];
# The scaffold guards both settings; NixOS may add its own access assertions.
assert builtins.length failedAssertions >= 2;
assert config.networking.hostName == "arbour-haus";
assert config.nixpkgs.hostPlatform.system == "x86_64-linux";
assert config.fileSystems."/".fsType == "tmpfs";
assert builtins.elem "size=25%" config.fileSystems."/".options;
assert config.fileSystems."/nix".fsType == "btrfs";
assert config.fileSystems."/persist".fsType == "btrfs";
assert config.fileSystems."/nix".neededForBoot;
assert config.fileSystems."/persist".neededForBoot;
assert builtins.elem "/etc/nixos" persistentDirectories;
assert builtins.elem "/var/lib/nixos" persistentDirectories;
assert builtins.elem "/etc/machine-id" persistentFiles;
assert builtins.all (key: builtins.elem key.path persistentFiles) config.services.openssh.hostKeys;
assert !(builtins.elem "/home" persistentDirectories);
assert config.fileSystems."/boot".fsType == "vfat";
assert !config.users.mutableUsers;
assert config.services.openssh.settings.PasswordAuthentication == false;
assert config.services.openssh.settings.PermitRootLogin == "no";
assert config.sops.age.sshKeyPaths == [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
assert builtins.elem "/etc/ssh/ssh_host_ed25519_key" persistentFiles;
assert config.sops.secrets == { };
assert !config.services.home-assistant.enable;
{
  # Evaluating these forces package/module validation, including NixOS
  # assertions, without requiring a Linux builder on a macOS development host.
  toplevel = config.system.build.toplevel.drvPath;
  disko = config.system.build.diskoScript.drvPath;
}
