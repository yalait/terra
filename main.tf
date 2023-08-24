provider "vcd" {
  user                   = ""
  password               = ""
  org                    = ""
  vdc                    = ""
  url                    = ""
}

#SET a TEMPLATE
#dunno why i'm defining 100500 variables or what is this shit? 
data "vcd_catalog" "my-catalog" {
  org  = "unix_u4"
  name = "VK_S3_TEMPL"
}
#same as above, i define catalog, now i must define fucking template, why i can define it in 1 command?
data "vcd_catalog_vapp_template" "centos7" {
  org        = "unix_u4"
  catalog_id = data.vcd_catalog.my-catalog.id
  name       = "vk-temp"
}

#variable for ssh_keys dunno how to specify this shit in another file annd iunclude to this bull shit
variable "ssh_key_private" {
  description = "Path to the private key file for SSH authentication"
  type        = string
  default     = "/root/.ssh/id_rsa"  # Replace with the actual path to your private key file
}

resource "vcd_vapp_vm" "TestVm" {
  #count it's like for_each, but not =D
  count = 3  # This will create three instances

  vapp_name     = "vk-storage"
  name          = "test-vm${count.index + 1}"
  computer_name = "test-vm${count.index + 1}"
  memory        = 2048
  cpus          = 2
  cpu_cores     = 1
  hardware_version = "vmx-15"

  #this stupidity shit must be specifed otherwise this shitty conf won't work
  os_type = "centos7_64Guest"
  #calling a template from where we will deploy the vm
  vapp_template_id = data.vcd_catalog_vapp_template.centos7.id
  # Other instance-specific configurations here...

  #shit network work's for vcd only, cloud-init won't eat this shit
  network {
    adapter_type       = "VMXNET3"
    connected          = true
    ip                 = "192.168.5.${count.index + 236}"
    ip_allocation_mode = "MANUAL"
    is_primary         = true
    name               = "s3_net"
    type               = "org"
  }
  
  #this shit must be defined otherwise metadata_entry shit won't work
  customization {
    enabled = true
  }
  #cloud-init https://registry.terraform.io/providers/vmware/vcd/latest/docs/resources/catalog.html#metadata_entry
  metadata_entry {
    key   = "user_data"
    value = templatefile("${path.module}/userdata.tpl", {
      ip_address = "192.168.5.${count.index + 236}"
      gateway    = "192.168.5.1"
      hostname  = "test-vm${count.index + 1}"
      dns_servers = "8.8.8.8"
    })
    is_system = false
    type      = "MetadataStringValue"
    user_access = "READWRITE"
  }
}

#Test vm dynamic inventory
#generating array with ip's
locals {
  vm_ips = flatten([
    for vm in vcd_vapp_vm.TestVm : [
      for network in vm.network : network.ip
    ]
  ])
}

#outputting the array with ip data
output "vm_ips" {
  value = local.vm_ips
}

#filling our template with data from array
resource "local_file" "hosts_cfg" {
  content = templatefile("${path.module}/hosts.tpl",
    {
      vm_ips = local.vm_ips
    }
  )
  filename = "hosts.cfg"
}

#ANSIBLE
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

