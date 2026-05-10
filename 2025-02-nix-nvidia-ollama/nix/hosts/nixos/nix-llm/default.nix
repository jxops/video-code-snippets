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

  # --- 1. PROMOTED PREP SERVICE ---
  # We move your initScript here so it finishes BEFORE Docker even tries to load
  systemd.services.nvidia-cdi-init = {
    description = "Wait for GPU and generate CDI spec";
    before = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      # This is your hard work, just moved to a safer spot
      ExecStart = pkgs.writeShellScript "docker-nvidia-init" ''
        # Give the kernel time to register /dev/nvidia0
        for i in {1..30}; do
          if [ -e /dev/nvidia0 ]; then break; fi
          sleep 1
        done

        # Ensure persistence so the driver stays 'awake'
        ${pkgs.linuxPackages.nvidia_x11.bin}/bin/nvidia-smi -pm 1 || true

        mkdir -p /etc/cdi
        rm -f /etc/cdi/*
        ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate \
          --format=json \
          --nvidia-ctk-path=${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk \
          --output=/etc/cdi/nvidia.json
      '';
    };
  };

  # --- 2. CLEANER DOCKER CONFIG ---
  virtualisation.docker.enable = true;
  virtualisation.docker.listenOptions = [];

  systemd.services.docker = {
    # Now Docker just waits for our Prep service to finish
    after = [ "network-online.target" "nvidia-cdi-init.service" ];
    requires = [ "nvidia-cdi-init.service" ];

    serviceConfig = {
      # Keep your safety net
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
