{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [ "${inputs.impermanence}/nixos.nix" ];

  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      {
        directory = "/etc/nixos";
        user = "root";
        group = "root";
        mode = "0755";
      }
      "/var/lib/nixos" # Stable UID/GID allocation and other NixOS state.
      "/var/lib/systemd" # Random seed and persistent timer state.
      "/var/log" # Bounded diagnostics across reboots.
    ]
    ++ lib.optionals config.networking.dhcpcd.enable [
      {
        directory = "/var/lib/dhcpcd";
        user = "dhcpcd";
        group = "dhcpcd";
        mode = "0750";
      }
    ];
    files = [
      "/etc/machine-id"
    ]
    ++ lib.concatMap (key: [
      key.path
      "${key.path}.pub"
    ]) config.services.openssh.hostKeys;
  };

  services.journald.extraConfig = ''
    SystemMaxUse=256M
  '';
  # Homes, /tmp and all unlisted service state are deliberately ephemeral.
  # Stateful modules must merge their own narrow persistence entries.
}
