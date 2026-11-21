{ config, pkgs, ... }:

{
  # Configures setcap wrappers to allow packet capture without root
  programs.wireshark.enable = true;

  environment.systemPackages = with pkgs; [
    nmap
    tcpdump
    mtr
    iperf3
    ipcalc
    gns3-gui
    gns3-server
    ubridge # Required by GNS3 to bridge simulated networks to physical LANs

    # Firewall, socket, route, and connection-tracking debugging
    nftables
    iproute2
    conntrack-tools
  ];
}
