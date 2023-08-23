#cloud-config
# userdata.tpl
# Cloud-init script template
ip_address  = "${ip_address}"
gateway     = "${gateway}"
hostname    = "${hostname}"
dns_servers = "${dns_servers}"

## DNS settings
#write_files:
  #- path: /etc/resolv.conf
    #content: |
      #nameserver 8.8.8.8
      #nameserver 8.8.4.4