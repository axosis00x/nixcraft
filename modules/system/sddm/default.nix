{
  config,
  lib,
  pkgs,
  inputs,
  settings,
  ...
}:
let
  cfg = config.systemSettings.sddm;
in
{
  imports = [ inputs.silentSDDM.nixosModules.default ];
  options.systemSettings.sddm = {
    enable = lib.mkEnableOption "SilentSDDM display manager";
    theme = lib.mkOption {
      type = lib.types.str;
      default = "ken";
      description = "SilentSDDM theme to use.";
    };
    user = lib.mkOption {
      type = lib.types.str;
      default = settings.username;
      description = "User to set the SDDM avatar for.";
    };
    avatar = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      description = "Default avatar image, used until the user picks one (~/.face).";
      default = ../../../assets/pfp.png;
    };
  };
  config = lib.mkIf cfg.enable {
    programs.silentSDDM = {
      enable = true;
      theme = cfg.theme;
    };

    systemd.tmpfiles.rules = lib.mkIf (cfg.avatar != null) [
      "f+ /var/lib/AccountsService/users/${cfg.user} 0600 root root - [User]\\nIcon=/var/lib/AccountsService/icons/${cfg.user}\\n"
    ];

    # The login screen can't read the user's (private) home, so copy their
    # profile picture, ~/.face (set from Settings, see
    # config/quickshell/scripts/pfp.sh), to where it looks, or the default
    # when there's none. Runs at boot and again whenever ~/.face changes.
    systemd.services.nixcraft-pfp-sync = lib.mkIf (cfg.avatar != null) {
      description = "Copy the profile picture to the login screen";
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script =
        let
          face = "${config.users.users.${cfg.user}.home}/.face";
          icon = "/var/lib/AccountsService/icons/${cfg.user}";
          # Read as the user, so a ~/.face symlink can't expose a file they
          # couldn't read themselves; capped at 16 MiB.
          asUser = "${pkgs.util-linux}/bin/runuser -u ${cfg.user} --";
        in
        ''
          mkdir -p /var/lib/AccountsService/icons
          if ! { ${asUser} test -f ${face} && ${asUser} head -c 16777216 ${face} > ${icon}.new; }; then
            cp -f ${cfg.avatar} ${icon}.new
          fi
          chmod 0644 ${icon}.new
          mv -f ${icon}.new ${icon}
        '';
    };
    systemd.paths.nixcraft-pfp-sync = lib.mkIf (cfg.avatar != null) {
      wantedBy = [ "multi-user.target" ];
      pathConfig.PathChanged = "${config.users.users.${cfg.user}.home}/.face";
    };
  };
}
