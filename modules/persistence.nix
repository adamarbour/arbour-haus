{ sources, ... }:
{
  flake.modules.nixos.persistence = { config, lib, ... }: {
    imports = [ "${sources.impermanence}/nixos.nix" ];

    environment.persistence."/persist" = {
      hideMounts = true;
      directories = [
        "/etc/nixos" # The checkout; exposed here from /persist/etc/nixos.
        "/var/lib/nixos" # Stable UID/GID allocation and other NixOS state.
        "/var/lib/systemd" # Random seed and persistent timer state.
        "/var/log" # Bounded diagnostics across reboots.
      ]
      ++ lib.optionals config.networking.dhcpcd.enable [
        {
          directory = "/var/lib/dhcpcd"; # Stable DHCP identity and leases.
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
    # Future service features must declare their own persistence here or merge
    # into environment.persistence."/persist".directories from their module.
  };
}
