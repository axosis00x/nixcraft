{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.systemSettings.gpu;
in
{
  options = {
    systemSettings.gpu = {
      enable = lib.mkEnableOption "Enable NVIDIA Optimus (Intel + NVIDIA hybrid) graphics";
    };
  };
  config = lib.mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      # Hyprland renders on the Intel iGPU (see envs.lua's mesa/iHD vars), but
      # without this package LIBVA_DRIVER_NAME=iHD has no driver to load, so
      # VAAPI silently fails and every screen recorder falls back to a
      # CPU-only software encode -- pegging the CPU and dropping frames.
      extraPackages = [ pkgs.intel-media-driver ];
    };
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };
}
