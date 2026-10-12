# Shared by every machine in hosts/: the system configuration plus a Home
# Manager user for each entry in systemSettings.users. A host folder only
# adds its settings.nix and hardware-configuration.nix (see flake.nix).
{ config, settings, ... }:

let
  # Optional per-machine Home Manager extras (hosts/<hostname>/home.nix).
  hostHome = ../../hosts + "/${settings.hostname}/home.nix";
in

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
          ]
          ++ (if builtins.pathExists hostHome then [ hostHome ] else [ ]);
          home.username = user;
          home.homeDirectory = config.users.users.${user}.home;
        };
      }) config.systemSettings.users
    );
  };
}
