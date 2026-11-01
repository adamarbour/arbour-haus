{
  # Initial target: a generic x86_64 machine/VM with UEFI firmware.
  system = "x86_64-linux";
  disk = "/dev/disk/by-id/ata-CT1000MX500SSD1_2306E6AB159A";
  adminAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICQ9qbDDtV+SRmc+KFO+RQlbWhUvyjwJPf+rPV4whbTo"
  ];
}
