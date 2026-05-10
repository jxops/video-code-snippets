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

  systemd.services.docker = {
    after = [ "network.target" "containerd.service" ];
    environment = {
      CDI_SPEC_DIRS = "/etc/cdi";
    };
    serviceConfig = {
      ExecStartPre = let
        # Create a tiny script to handle the generation safely
        initScript = pkgs.writeShellScript "docker-nvidia-init" ''
          # Wait for GPU
          until ${pkgs.nvtopPackages.full}/bin/nvidia-smi; do sleep 1; done

          # Clean and Generate
          mkdir -p /etc/cdi
          rm -f /etc/cdi/*
          ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate \
            --format=json \
            --nvidia-ctk-path=${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk \
            --output=/etc/cdi/nvidia.json
        '';
      in [
        # The '+' runs this as root
        "+${initScript}"
      ];
    };
  };

  virtualisation.docker.enable = true;

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
