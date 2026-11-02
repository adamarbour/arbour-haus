{ pkgs, ... }:
{
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  networking.useDHCP = true;
  networking.firewall.enable = true;

  nix.channel.enable = false;
  nix.nixPath = [ ];
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    flake-registry = "";
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  programs.command-not-found.enable = false;
  environment.systemPackages = with pkgs; [
    git
    vim
    # SSH clients forward TERM=xterm-ghostty; install only the terminal database.
    ghostty.terminfo
  ];
  # Home Assistant and its firewall ports intentionally remain disabled.
}
