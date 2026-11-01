# TEST ONLY. This key is deliberately unusable and the disk is fictitious.
# Never import this file from production entry points or installation scripts.
{
  system = "x86_64-linux";
  disk = "/dev/disk/by-id/fixture-only";
  adminAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA eval-only"
  ];
}
