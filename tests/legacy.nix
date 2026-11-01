let
  sources = import ../npins;
  project = import ../. { };
  direct = project.nixosConfigurations.arbour-haus.config;
  legacy =
    (import "${sources.nixpkgs}/nixos/lib/eval-config.nix" {
      system = null;
      modules = [ ../configuration.nix ];
    }).config;
in
# Do not force production build assertions: a new checkout has no disk/key yet.
assert legacy.networking.hostName == direct.networking.hostName;
assert legacy.nixpkgs.hostPlatform.system == direct.nixpkgs.hostPlatform.system;
assert legacy.fileSystems == direct.fileSystems;
assert legacy.services.openssh.settings == direct.services.openssh.settings;
assert legacy.sops.age.sshKeyPaths == direct.sops.age.sshKeyPaths;
true
