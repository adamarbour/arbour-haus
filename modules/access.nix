{ hostSettings, ... }:
{
  flake.modules.nixos.access = {
    assertions = [
      {
        assertion = hostSettings.adminAuthorizedKeys != [ ];
        message = "Set adminAuthorizedKeys in host-settings.nix before deploying (SSH is key-only).";
      }
    ];

    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    # Account state is rebuilt from configuration on the ephemeral root.
    users.mutableUsers = false;
    users.users.admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = hostSettings.adminAuthorizedKeys;
    };
    # The admin has no password; an SSH key grants administrative access.
    security.sudo.wheelNeedsPassword = false;
    users.users.root.hashedPassword = "!";
  };
}
