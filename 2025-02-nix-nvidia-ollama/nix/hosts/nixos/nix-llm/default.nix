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

    # This environment variable forces Docker to look in our custom directory
    environment = {
      CDI_SPEC_DIRS = "/etc/cdi";
    };

    serviceConfig = {
      ExecStartPre = [
        "+/run/current-system/sw/bin/bash -c 'until /run/current-system/sw/bin/nvidia-smi; do sleep 1; done'"

        # 1. Ensure the directory exists
        "+/run/current-system/sw/bin/mkdir -p /etc/cdi"

        # 2. Generate the spec with JSON format explicitly defined
        # We use /etc/cdi/nvidia.json as a stable, persistent home.
        "+/run/current-system/sw/bin/nvidia-ctk cdi generate --format=json --output=/etc/cdi/nvidia.json"

        # 3. Create the symlink to the location we know Docker straced, just for double coverage
        "+/run/current-system/sw/bin/mkdir -p /var/run/cdi"
        "+/run/current-system/sw/bin/ln -sf /etc/cdi/nvidia.json /var/run/cdi/nvidia-container-toolkit.json"

        "+/run/current-system/sw/bin/sync"
        "+/run/current-system/sw/bin/sleep 2"
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
