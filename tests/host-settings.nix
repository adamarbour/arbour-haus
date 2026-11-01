# TEST ONLY. This key is deliberately unusable and /dev/vda is a VM fixture.
# Never import this file from production entry points or installation scripts.
{
  system = "x86_64-linux";
  disk = "/dev/vda";
  adminAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA eval-only"
  ];
}
