{
  config,
  sources,
  hostSettings,
  ...
}:
{
  flake.modules.nixos.host = { lib, ... }: {
    imports = with config.flake.modules.nixos; [
      base
      access
      storage
      persistence
      secrets
    ];

    nixpkgs.hostPlatform = hostSettings.system;
    networking.hostName = "arbour-haus";
    # Generic PC/VM baseline. Add hardware-specific modules here after
    # inspecting nixos-generate-config --show-hardware-config on the target.
    boot.initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "sd_mod"
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
    ];
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

    # Installation compatibility version, not the nixpkgs update target.
    system.stateVersion = "26.05";
  };

  flake.nixosConfigurations.arbour-haus = import "${sources.nixpkgs}/nixos/lib/eval-config.nix" {
    system = null;
    modules = [ config.flake.modules.nixos.host ];
  };
}
