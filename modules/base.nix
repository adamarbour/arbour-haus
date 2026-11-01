{ sources, ... }:
{
  flake.modules.nixos.base = { pkgs, ... }: {
    time.timeZone = "UTC";
    i18n.defaultLocale = "en_US.UTF-8";

    networking.useDHCP = true;
    networking.firewall.enable = true;

    # Keep legacy commands on exactly the same nixpkgs as this configuration.
    nix.nixPath = [ "nixpkgs=${sources.nixpkgs}" ];
    nix.channel.enable = false;
    nix.settings.auto-optimise-store = true;
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # No channel-provided command database is needed on this server.
    programs.command-not-found.enable = false;
    environment.systemPackages = with pkgs; [
      git
      vim
    ];
    # Home Assistant and its firewall ports intentionally remain disabled.
  };
}
