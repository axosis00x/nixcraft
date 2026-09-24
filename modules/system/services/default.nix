{
  config,
  lib,
  ...
}:
let
  cfg = config.systemSettings.services;
in
{
  options = {
    systemSettings.services = {
      enable = lib.mkEnableOption "Enable core system services";
    };
  };
  config = lib.mkIf cfg.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;

    services.power-profiles-daemon.enable = true;

    networking.firewall = {
      enable = false;
    #   allowedTCPPorts = [ ];
    #   allowedUDPPorts = [ ];
    };

    services.fstrim.enable = true;
    services.earlyoom.enable = true;
    services.fwupd.enable = true;

    services.printing.enable = true;
    zramSwap.enable = true;

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    security.rtkit.enable = true;

    services.gvfs.enable = true;
    services.udisks2.enable = true;

    services.timesyncd.enable = true;

    services.openssh = {
      enable = false;
      settings.PasswordAuthentication = false;
    };
  };
}
