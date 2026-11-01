# CI only: actually build the fixture closure without real deployment settings.
let
  project = import ../. { hostSettings = import ./host-settings.nix; };
  build = project.nixosConfigurations.arbour-haus.config.system.build;
in
{
  system = build.toplevel;
  disko = build.diskoScript;
}
