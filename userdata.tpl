#cloud-config
network:
  version: 2
  ethernets:
    ens192:
      dhcp4: false
      addresses:
        - ${ip_address}/24
      gateway4: 192.168.5.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4

bootcmd:
  - echo nameserver 8.8.4.4 >> /etc/resolv.conf
