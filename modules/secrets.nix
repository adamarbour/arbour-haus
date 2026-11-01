{ inputs, ... }:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # Read the persistent backing identity directly, before /etc links exist.
  # OpenSSH generates it at first boot; no secrets are required for enrollment.
  sops.age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
  sops.gnupg.sshKeyPaths = [ ];
}
