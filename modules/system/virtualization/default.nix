{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.systemSettings.virtualization;
in
{
  options.systemSettings.virtualization = {
    enable = lib.mkEnableOption "virt-manager and Waydroid";
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      virt-manager
      pkgs.wl-clipboard
    ];
    hardware.graphics.enable32Bit = true;
    virtualisation.libvirtd.enable = true;
    virtualisation.waydroid.enable = true;
    virtualisation.waydroid.package = pkgs.waydroid-nftables;
    programs.virt-manager.enable = true;
    users.users.axosis00x.extraGroups = [ "libvirtd" ];
  };
}
