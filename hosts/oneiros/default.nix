{ config, ... }:

{
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
  ];

  config = {
    home-manager.users = builtins.listToAttrs (
      map (user: {
        name = user;
        value = {
          imports = [
            ./home.nix
            ../../modules/user
          ];
          home.username = user;
          home.homeDirectory = "/home/${user}";
        };
      }) config.systemSettings.users
    );
  };
}
