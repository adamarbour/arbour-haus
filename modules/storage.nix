{ sources, hostSettings, ... }:
{
  flake.modules.nixos.storage = {
    imports = [ "${sources.disko}/module.nix" ];
    assertions = [
      {
        assertion = hostSettings.disk != "/dev/disk/by-id/REPLACE-ME";
        message = "Set disk in host-settings.nix to the target disk's persistent /dev/disk/by-id path.";
      }
    ];

    # DESTRUCTIVE when running diskoScript: this entire disk is erased.
    disko.devices.nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "mode=755"
        "size=25%"
      ];
    };

    # Mount persistent state before activation and early secret consumers.
    fileSystems."/persist".neededForBoot = true;
    fileSystems."/nix".neededForBoot = true;

    disko.devices.disk.system = {
      type = "disk";
      device = hostSettings.disk;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          store = {
            size = "100%";
            content = {
              type = "btrfs";
              subvolumes = {
                "@nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
              };
            };
          };
        };
      };
    };
    services.fstrim.enable = true;
  };
}
