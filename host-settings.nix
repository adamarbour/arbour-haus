{
  # Initial target: a generic x86_64 machine/VM with UEFI firmware.
  system = "x86_64-linux";
  disk = "/dev/disk/by-id/REPLACE-ME";
  # Public keys only. Both values must be configured before installation.
  adminAuthorizedKeys = [ ];
}
