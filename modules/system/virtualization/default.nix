{
  config,
  lib,
  pkgs,
  settings,
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
    users.users.${settings.username}.extraGroups = [ "libvirtd" ];

    # libvirt's "default" NAT network (virbr0) isn't started on its own, and
    # VMs attached to it then refuse to boot ("network 'default' is not
    # active"). Bring it up once libvirtd is running, on every boot.
    systemd.services.libvirt-default-network = {
      description = "Start libvirt's default NAT network";
      after = [ "libvirtd.service" ];
      requires = [ "libvirtd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        virsh=${pkgs.libvirt}/bin/virsh
        $virsh net-info default | grep -q '^Active: *yes' || $virsh net-start default
      '';
    };
    # Let VMs on that network reach dnsmasq for DHCP and DNS.
    networking.firewall.trustedInterfaces = [ "virbr0" ];
  };
}
