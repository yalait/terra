provider "vcd" {
  user                   = ""
  password               = ""
  org                    = ""
  vdc                    = ""
  url                    = ""
}

#SET a TEMPLATE
data "vcd_catalog" "my-catalog" {
  org  = "unix_u4"
  name = "VK_S3_TEMPL"
}

data "vcd_catalog_vapp_template" "centos7" {
  org        = "unix_u4"
  catalog_id = data.vcd_catalog.my-catalog.id
  name       = "vk-temp"
}

#КАКОЙ-ТО ЕБАНЫЙ НЕЗАВИСИМЫЙ ДИСК
#resource "vcd_independent_disk" "disk" {
#  count = 3
#  name         = "logDisk${count.index + 1}"
#  size_in_mb   = "10512"
#  bus_type     = "SCSI"
#  bus_sub_type = "VirtualSCSI"
#}

resource "vcd_vapp_vm" "TestVm" {
  count = 3  # This will create three instances

  vapp_name     = "vk-storage"
  name          = "test-vm${count.index + 1}"
  computer_name = "test-vm${count.index + 1}"
  memory        = 2048
  cpus          = 2
  cpu_cores     = 1
  hardware_version = "vmx-15"

  os_type = "centos7_64Guest"
  #call a template
  vapp_template_id = data.vcd_catalog_vapp_template.centos7.id
  # Other instance-specific configurations here...

  network {
    adapter_type       = "VMXNET3"
    connected          = true
    ip                 = "192.168.5.${count.index + 236}"
    ip_allocation_mode = "MANUAL"
    is_primary         = true
    name               = "s3_net"
    type               = "org"
  }

#SHIT FUNCTION not mentioned in https://registry.terraform.io/providers/vmware/vcd/latest/docs this bull shit override your template disk while creating vm
  override_template_disk {
    bus_type = "paravirtual"
    size_in_mb = "32768"
    bus_number = 0
    unit_number = 0
    #storage_profile = var.vcd_org_ssd_sp
}

#  disk {
#    name        = "disk${count.index + 1}"
#    #label       = "disk${count.index + 1}"
#    #size        = 4000
#    unit_number = count.index + 2
#    bus_number = 2
#  }
  customization {
    enabled = true
  }
  #cloud-shit https://registry.terraform.io/providers/vmware/vcd/latest/docs/resources/catalog.html#metadata_entry
  metadata_entry {
    key   = "user_data"
    value = templatefile("${path.module}/userdata.tpl", {
      ip_address = "192.168.5.${count.index + 236}"
      gateway    = "192.168.5.1"
      hostname  = "test-vm${count.index + 1}"
      dns_servers = "8.8.4.4"
    })
    is_system = false
    type      = "MetadataStringValue"
    user_access = "READWRITE"
  }
}

#Test vm dynamic inventory
locals {
  vm_ips = flatten([
    for vm in vcd_vapp_vm.TestVm : [
      for network in vm.network : network.ip
    ]
  ])
}

output "vm_ips" {
  value = local.vm_ips
}


resource "local_file" "hosts_cfg" {
  content = templatefile("${path.module}/hosts.tpl",
    {
      vm_ips = local.vm_ips
    }
  )
  filename = "hosts.cfg"
}

resource "null_resource" "ansible_provisioner" {
  count = length(local.vm_ips)

  triggers = {
    vm_index = count.index
  }

  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook -i "${path.module}/hosts.cfg" \
                       -u onlanta provision.yml
    EOT
  }
}
