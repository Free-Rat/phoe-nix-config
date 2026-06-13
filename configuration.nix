{ config, pkgs, ... }:

{
  imports = builtins.filter builtins.pathExists [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "UTC";

  i18n.defaultLocale = "en_US.UTF-8";

  users.mutableUsers = false;

  users.users.user = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    password = "user";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFyt0Y9Q14Yui8hUpPd0mfPSqEBcafylUmT4ItfRYxXG maliketh"
    ];
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    sl
    figlet
    toilet
  ];

  services.openssh.enable = true;
  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "24.11";
}