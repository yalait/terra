terraform {
  required_version = ">= 0.13"

  required_providers {
    #vsphere = {
      #source = "hashicorp/vsphere"
    #}
    #avi = {
      #source  = "vmware/avi"
      #version = "21.1.3"
    #}
    #nsxt = {
      #source = "vmware/nsxt"
    #}
    vcd = {
      source = "vmware/vcd"
    }
  }
}
