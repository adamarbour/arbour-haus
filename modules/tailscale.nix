{ ... }:
{
  services.tailscale = {
    enable = true;
    openFirewall = true; # UDP tunnel transport; not a public application port.
    useRoutingFeatures = "none";
    disableTaildrop = true;
    # Enroll interactively over LAN SSH; no first-boot secret dependency.
    # Keep OpenSSH as the sole SSH authentication mechanism.
    extraSetFlags = [ "--ssh=false" ];
  };

  environment.persistence."/persist".directories = [
    {
      directory = "/var/lib/tailscale";
      user = "root";
      group = "root";
      mode = "0700";
    }
  ];
  # Do not trust the entire interface or enable subnet/exit-node routing.
  # OpenSSH's existing TCP 22 firewall rule also applies over tailscale0.
}
