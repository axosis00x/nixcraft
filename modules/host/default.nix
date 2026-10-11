# Shared by every machine in hosts/: the system configuration plus a Home
# Manager user for each entry in systemSettings.users. A host folder only
# adds its settings.nix and hardware-configuration.nix (see flake.nix).
{ config, ... }:

{
  imports = [
    ./configuration.nix
  ];

  config = {
    home-manager.users = builtins.listToAttrs (
      map (user: {
        name = user;
        value = {
          imports = [
            ./home.nix
            ../user
          ];
          home.username = user;
          home.homeDirectory = "/home/${user}";
        };
      }) config.systemSettings.users
    );
  };
}
