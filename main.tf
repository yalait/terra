provider "vcd" {
  user                   = ""
  password               = ""
  org                    = ""
  vdc                    = ""
  url                    = ""
}

#используется для извлечения информации о каталоге из VMware Cloud Director (vCD).
data "vcd_catalog" "my-catalog" {
  org  = "unix_u4"
  name = "VK_S3_TEMPL"
}
#представляет конфигурацию Terraform для извлечения информации о шаблоне виртуальной машины из каталога VMware Cloud Director (vCD).
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

#представляет конфигурацию Terraform для создания или управления виртуальной машиной в VMware Cloud Director (vCD).
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
  #используется для получения идентификатора (ID) шаблона виртуальной машины из ранее извлеченной информации с использованием блока data "vcd_catalog_vapp_template" "centos7".
  vapp_template_id = data.vcd_catalog_vapp_template.centos7.id
  # Other instance-specific configurations here...

  network {
    adapter_type       = "VMXNET3"
    connected          = true
    ip                 = "192.168.5.${count.index + 60}"
    ip_allocation_mode = "MANUAL"
    is_primary         = true
    name               = "s3_net"
    type               = "org"
  }

#SHIT FUNCTION not mentioned in https://registry.terraform.io/providers/vmware/vcd/latest/docs this bull shit override your template disk while creating vm
#переопределить дисковые параметры для создания виртуальной машины на основе шаблона виртуальной машины.
  override_template_disk {
    bus_type = "paravirtual"
    size_in_mb = "32768"
    bus_number = 0
    unit_number = 0
    #storage_profile = var.vcd_org_ssd_sp
}

#блок используется для определения параметров, которые позволяют настроить виртуальную машину на этапе развертывания.
  customization {
    enabled = true
  }
}

#Фрагмент кода, который вы предоставили, использует блок locals в Terraform для создания переменной, которая будет содержать список IP-адресов виртуальных машин, определенных в ресурсе vcd_vapp_vm.TestVm.
locals {
  vm_ips = flatten([
    for vm in vcd_vapp_vm.TestVm : [
      for network in vm.network : network.ip
    ]
  ])
}

#в Terraform используется для создания вывода, который предоставляет доступ к определенным значениям или переменным из вашей конфигурации Terraform после её выполнения. В данном случае, output "vm_ips" позволяет вам создать вывод с именем vm_ips и присвоить ему значение, которое содержится в переменной local.vm_ips.
output "vm_ips" {
  value = local.vm_ips
}

#Фрагмент resource "local_file" "hosts_cfg" в Terraform используется для создания файла на локальной системе на основе содержимого и шаблона. В данном случае, этот ресурс используется для создания файла hosts.cfg на основе шаблона hosts.tpl, подставляя значения из переменной local.vm_ips в шаблон.
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
