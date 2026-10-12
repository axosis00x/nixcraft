{
  description = "nixcraft: NixOS + Hyprland + Quickshell";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    apple-fonts = {
      url = "github:Lyndeno/apple-fonts.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
      };
    };
    spicetify-nix = {
      url = "github:Gerg-L/spicetify-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    momoi-say = {
      url = "github:haruki-nikaidou/momoisay-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprmod = {
      url = "github:BlueManCZ/hyprmod";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      ...
    }:
    let
      lib = nixpkgs.lib;

      # Every folder in hosts/ with a settings.nix is a machine, named after
      # its hostname. Adding a machine is adding a folder (./install.sh does
      # it); they never overwrite each other.
      hostNames = lib.attrNames (
        lib.filterAttrs (
          name: type: type == "directory" && builtins.pathExists (./hosts + "/${name}/settings.nix")
        ) (builtins.readDir ./hosts)
      );

      # A host's settings.nix, checked against modules/settings.nix (types,
      # unknown names) and filled in with its defaults.
      mkSettings =
        hostname:
        let
          file = ./hosts + "/${hostname}/settings.nix";
          settings =
            (lib.evalModules {
              modules = [
                ./modules/settings.nix
                file
                { inherit hostname; }
              ];
            }).config;
        in
        lib.throwIf (settings.boot.loader == "grub" && settings.boot.grubDevice == "")
          "${toString file}: boot.loader = \"grub\" needs boot.grubDevice (the boot disk, e.g. /dev/sda)."
          settings;

      mkHost =
        hostname:
        let
          settings = mkSettings hostname;
        in
        lib.nixosSystem {
          specialArgs = {
            inherit inputs settings;
          };
          modules = [
            { nixpkgs.hostPlatform = settings.system; }
            ./modules/host
            (./hosts + "/${hostname}/hardware-configuration.nix")
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "backup";
              home-manager.extraSpecialArgs = { inherit inputs settings; };
            }
          ];
        };

      # Checks and the formatter run on the build machine's platform.
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Runs `script` in a copy of this repo (git-tracked files only); the
      # check passes if it exits 0.
      repoCheck =
        name: tools: script:
        pkgs.runCommand "nixcraft-${name}" { nativeBuildInputs = tools; } ''
          cd ${self}
          ${script}
          touch $out
        '';
    in
    {
      nixosConfigurations = lib.genAttrs hostNames mkHost;

      # `nix fmt` formats every .nix file except the generated hardware ones.
      formatter.${system} = pkgs.nixfmt-tree.override {
        settings.formatter.nixfmt.excludes = [ "hosts/*/hardware-configuration.nix" ];
      };

      # `nix flake check` runs these and also evaluates every host above;
      # CI runs the same command (.github/workflows/check.yml).
      checks.${system} = {
        format = repoCheck "format" [ pkgs.nixfmt ] ''
          find . -name '*.nix' ! -path './hosts/*/hardware-configuration.nix' -print0 |
            xargs -0 nixfmt --check
        '';
        shellcheck = repoCheck "shellcheck" [ pkgs.shellcheck ] ''
          find . -name '*.sh' -print0 | xargs -0 shellcheck -S warning
        '';
        lua = repoCheck "lua" [ pkgs.lua5_4 ] ''
          find . -name '*.lua' -print0 | xargs -0 -n1 luac -p
        '';
      };
    };
}
