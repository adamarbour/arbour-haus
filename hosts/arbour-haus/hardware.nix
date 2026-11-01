{ lib, ... }:
{
  # Generic UEFI PC/VM baseline. Review the target's generated hardware config
  # before installation; disko, not this file, owns all filesystem declarations.
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
}
