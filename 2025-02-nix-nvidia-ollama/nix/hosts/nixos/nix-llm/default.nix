{ config, inputs, pkgs, name, lib, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./../../common/nixos-common.nix
      ./../../common/common-packages.nix
    ];

  # Boot configuration
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  # 1. Disable the socket to prevent "trigger-happy" starts
  virtualisation.docker.enable = true;
  virtualisation.docker.listenOptions = []; # This helps disable socket activation quirks

  systemd.services.docker = {
    after = [ "network-online.target" "nvidia-persistenced.service" ];
    wants = [ "network-online.target" "nvidia-persistenced.service" ];

    serviceConfig = {
      # Give the kernel 10 extra seconds to finish driver registration
      ExecStartPre = let
        initScript = pkgs.writeShellScript "docker-nvidia-init" ''
          sleep 10
          mkdir -p /etc/cdi
          rm -f /etc/cdi/*
          ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate \
            --format=json \
            --nvidia-ctk-path=${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk \
            --output=/etc/cdi/nvidia.json || true
        '';
      in [ "+${initScript}" ];

      # If the container fails (Exit 128), systemd will restart the daemon itself
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
 
  # Network configuration
  networking = {
    firewall.enable = false;
    hostName = "nix-llm";
    interfaces.ens18 = {
      useDHCP = false;
      ipv4.addresses = [{
        address = "192.168.0.252";
        prefixLength = 24;
      }];
    };
    defaultGateway = "192.168.0.1";
    nameservers = [ "192.168.0.1" ];
  };

  # System localization
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  services.xserver = {
    enable = false;
    videoDrivers = [ "nvidia" ];
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
    settings.PermitRootLogin = "yes";
  };
  services.qemuGuest.enable = true;
  services.tailscale.enable = true;
  # services.ollama = {
  #   enable = true;
  #   host = "0.0.0.0";
  # };

  # userland
  #home-manager.useGlobalPkgs = true;
  #home-manager.useUserPackages = true;
  #home-manager.users.zaphod = { imports = [ ./../../../home/zaphod.nix ]; };
  users.users.zaphod = {
    isNormalUser = true;
    description = "zaphod";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    packages = with pkgs; [
      #home-manager
    ];
  };

  environment.systemPackages = with pkgs; [
    nvidia-container-toolkit
  ];

  # Hardware configuration
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = {
      modesetting.enable = true;
      open = false;
      nvidiaSettings = true;
      powerManagement.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
    nvidia-container-toolkit.enable = true;
  };

}
