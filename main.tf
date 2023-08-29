provider "vcd" {
  user     = ""
  password = ""
  org      = ""
  vdc      = ""
  url      = ""
}

#используется для извлечения информации о каталоге из VMware Cloud Director (vCD).
data "vcd_catalog" "my-catalog" {
  org  = var.org_name
  name = "VK_S3_TEMPL"
}
#представляет конфигурацию Terraform для извлечения информации о шаблоне виртуальной машины из каталога VMware Cloud Director (vCD).
data "vcd_catalog_vapp_template" "centos7" {
  org        = var.org_name
  catalog_id = data.vcd_catalog.my-catalog.id
  name       = "vk-temp"
}

#STORAGE
resource "vcd_independent_disk" "stor" {
  count        = var.vm_count
  name         = "stor${count.index + 1}"
  size_in_mb   = "307200"
  bus_type     = "SCSI"
  bus_sub_type = "VirtualSCSI"
}
resource "vcd_independent_disk" "storage" {
  depends_on   = [vcd_independent_disk.stor]
  count        = var.vm_count
  name         = "storage${count.index + 1}"
  size_in_mb   = "307200"
  bus_type     = "SCSI"
  bus_sub_type = "VirtualSCSI"
}

#META
resource "vcd_independent_disk" "meta" {
  depends_on   = [vcd_independent_disk.storage]
  count        = var.vm_count
  name         = "meta${count.index + 1}"
  size_in_mb   = "153600"
  bus_type     = "SCSI"
  bus_sub_type = "VirtualSCSI"
}

#STORAGE
#представляет конфигурацию Terraform для создания или управления виртуальной машиной в VMware Cloud Director (vCD).
resource "vcd_vapp_vm" "storage" {
  depends_on = [vcd_independent_disk.meta]
  count      = var.vm_count # This will create three instances

  vapp_name        = "vk-storage"
  name             = "storage-${count.index + 1}"
  computer_name    = "storage-${count.index + 1}"
  memory           = 6144
  cpus             = 6
  cpu_cores        = 1
  hardware_version = "vmx-15"

  os_type = "centos7_64Guest"
  #используется для получения идентификатора (ID) шаблона виртуальной машины из ранее извлеченной информации с использованием блока data "vcd_catalog_vapp_template" "centos7".
  vapp_template_id = data.vcd_catalog_vapp_template.centos7.id
  # Other instance-specific configurations here...

  network {
    adapter_type       = "VMXNET3"
    connected          = true
    ip                 = "192.168.5.${count.index + 25}"
    ip_allocation_mode = "MANUAL"
    is_primary         = true
    name               = "s3_net"
    type               = "org"
  }

  #SHIT FUNCTION not mentioned in https://registry.terraform.io/providers/vmware/vcd/latest/docs this bull shit override your template disk while creating vm
  #переопределить дисковые параметры для создания виртуальной машины на основе шаблона виртуальной машины.
  override_template_disk {
    bus_type    = "paravirtual"
    size_in_mb  = "32768"
    bus_number  = 0
    unit_number = 0
    #storage_profile = var.vcd_org_ssd_sp
  }

  dynamic "disk" {
    for_each = vcd_independent_disk.stor
    content {
      name        = disk.stor[count.index].name
      bus_number  = 1
      unit_number = 0
    }
  }

  disk {
    name        = vcd_independent_disk.stor[count.index].name
    bus_number  = 1
    unit_number = 0
  }
  disk {
    name        = vcd_independent_disk.storage[count.index].name
    bus_number  = 1
    unit_number = 1
  }

  #блок используется для определения параметров, которые позволяют настроить виртуальную машину на этапе развертывания.
  customization {
    enabled = true
  }
}

#META
#STORAGE
#представляет конфигурацию Terraform для создания или управления виртуальной машиной в VMware Cloud Director (vCD).
resource "vcd_vapp_vm" "meta" {
  depends_on = [vcd_vapp_vm.storage]
  count      = 3 # This will create three instances

  vapp_name        = "vk-meta"
  name             = "meta-${count.index + 1}"
  computer_name    = "meta-${count.index + 1}"
  memory           = 18432
  cpus             = 10
  cpu_cores        = 1
  hardware_version = "vmx-15"

  os_type = "centos7_64Guest"
  #используется для получения идентификатора (ID) шаблона виртуальной машины из ранее извлеченной информации с использованием блока data "vcd_catalog_vapp_template" "centos7".
  vapp_template_id = data.vcd_catalog_vapp_template.centos7.id
  # Other instance-specific configurations here...

  network {
    adapter_type       = "VMXNET3"
    connected          = true
    ip                 = "192.168.5.${count.index + 15}"
    ip_allocation_mode = "MANUAL"
    is_primary         = true
    name               = "s3_net"
    type               = "org"
  }

  #SHIT FUNCTION not mentioned in https://registry.terraform.io/providers/vmware/vcd/latest/docs this bull shit override your template disk while creating vm
  #переопределить дисковые параметры для создания виртуальной машины на основе шаблона виртуальной машины.
  override_template_disk {
    bus_type    = "paravirtual"
    size_in_mb  = "32768"
    bus_number  = 0
    unit_number = 0
    #storage_profile = var.vcd_org_ssd_sp
  }

  disk {
    name        = vcd_independent_disk.meta[count.index].name
    bus_number  = 1
    unit_number = 0
  }

  #блок используется для определения параметров, которые позволяют настроить виртуальную машину на этапе развертывания.
  customization {
    enabled = true
  }
}

#FRONT
#представляет конфигурацию Terraform для создания или управления виртуальной машиной в VMware Cloud Director (vCD).
resource "vcd_vapp_vm" "front" {
  depends_on = [vcd_vapp_vm.meta]
  count      = 2 # This will create three instances

  vapp_name        = "vk-front"
  name             = "front-${count.index + 1}"
  computer_name    = "front-${count.index + 1}"
  memory           = 16384
  cpus             = 8
  cpu_cores        = 1
  hardware_version = "vmx-15"

  os_type = "centos7_64Guest"
  #используется для получения идентификатора (ID) шаблона виртуальной машины из ранее извлеченной информации с использованием блока data "vcd_catalog_vapp_template" "centos7".
  vapp_template_id = data.vcd_catalog_vapp_template.centos7.id
  # Other instance-specific configurations here...

  network {
    adapter_type       = "VMXNET3"
    connected          = true
    ip                 = "192.168.5.${count.index + 4}"
    ip_allocation_mode = "MANUAL"
    is_primary         = true
    name               = "s3_net"
    type               = "org"
  }

  #SHIT FUNCTION not mentioned in https://registry.terraform.io/providers/vmware/vcd/latest/docs this bull shit override your template disk while creating vm
  #переопределить дисковые параметры для создания виртуальной машины на основе шаблона виртуальной машины.
  override_template_disk {
    bus_type    = "paravirtual"
    size_in_mb  = "32768"
    bus_number  = 0
    unit_number = 0
    #storage_profile = var.vcd_org_ssd_sp
  }

  #блок используется для определения параметров, которые позволяют настроить виртуальную машину на этапе развертывания.
  customization {
    enabled = true
  }
}

#MONITOR
#представляет конфигурацию Terraform для создания или управления виртуальной машиной в VMware Cloud Director (vCD).
resource "vcd_vapp_vm" "monitoring" {
  depends_on       = [vcd_vapp_vm.front]
  vapp_name        = "vk-monitoring"
  name             = "monitor-1"
  computer_name    = "monitor-1"
  memory           = 12288
  cpus             = 6
  cpu_cores        = 1
  hardware_version = "vmx-15"

  os_type = "centos7_64Guest"
  #используется для получения идентификатора (ID) шаблона виртуальной машины из ранее извлеченной информации с использованием блока data "vcd_catalog_vapp_template" "centos7".
  vapp_template_id = data.vcd_catalog_vapp_template.centos7.id
  # Other instance-specific configurations here...

  network {
    adapter_type       = "VMXNET3"
    connected          = true
    ip                 = "192.168.5.3"
    ip_allocation_mode = "MANUAL"
    is_primary         = true
    name               = "s3_net"
    type               = "org"
  }

  #блок используется для определения параметров, которые позволяют настроить виртуальную машину на этапе развертывания.
  customization {
    enabled = true
  }
}

#BALANCER
#представляет конфигурацию Terraform для создания или управления виртуальной машиной в VMware Cloud Director (vCD).
resource "vcd_vapp_vm" "balancer" {
  depends_on       = [vcd_vapp_vm.monitoring]
  vapp_name        = "vk-balancer"
  name             = "balancer-1"
  computer_name    = "balancer-1"
  memory           = 6144
  cpus             = 4
  cpu_cores        = 1
  hardware_version = "vmx-15"

  os_type = "centos7_64Guest"
  #используется для получения идентификатора (ID) шаблона виртуальной машины из ранее извлеченной информации с использованием блока data "vcd_catalog_vapp_template" "centos7".
  vapp_template_id = data.vcd_catalog_vapp_template.centos7.id
  # Other instance-specific configurations here...

  network {
    adapter_type       = "VMXNET3"
    connected          = true
    ip                 = "192.168.5.10"
    ip_allocation_mode = "MANUAL"
    is_primary         = true
    name               = "s3_net"
    type               = "org"
  }

  #блок используется для определения параметров, которые позволяют настроить виртуальную машину на этапе развертывания.
  customization {
    enabled = true
  }
}

#IAM
#представляет конфигурацию Terraform для создания или управления виртуальной машиной в VMware Cloud Director (vCD).
resource "vcd_vapp_vm" "iam" {
  depends_on       = [vcd_vapp_vm.balancer]
  vapp_name        = "S3"
  name             = "iam"
  computer_name    = "iam"
  memory           = 4096
  cpus             = 4
  cpu_cores        = 1
  hardware_version = "vmx-15"

  os_type = "centos7_64Guest"
  #используется для получения идентификатора (ID) шаблона виртуальной машины из ранее извлеченной информации с использованием блока data "vcd_catalog_vapp_template" "centos7".
  vapp_template_id = data.vcd_catalog_vapp_template.centos7.id
  # Other instance-specific configurations here...

  network {
    adapter_type       = "VMXNET3"
    connected          = true
    ip                 = "192.168.5.6"
    ip_allocation_mode = "MANUAL"
    is_primary         = true
    name               = "s3_net"
    type               = "org"
  }

  #блок используется для определения параметров, которые позволяют настроить виртуальную машину на этапе развертывания.
  customization {
    enabled = true
  }
}

#СОЗДАЁМ переменные с данными,так как мы создаём через count, то данные в массиве, циклом вытаскиваем то что нам надо
#Фрагмент кода, который вы предоставили, использует блок locals в Terraform для создания переменной, которая будет содержать список IP-адресов виртуальных машин,
# определенных в ресурсе vcd_vapp_vm.xxx
locals {
  #STOR
  vm_ips_storage = flatten([
    for vm in vcd_vapp_vm.storage : [
      for network in vm.network : network.ip
    ]
  ])
  vm_names_storage = [
    for vm_instance in vcd_vapp_vm.storage : vm_instance.computer_name
  ]
  #---
  #META
  vm_ips_meta = flatten([
    for vm in vcd_vapp_vm.meta : [
      for network in vm.network : network.ip
    ]
  ])
  vm_names_meta = [
    for vm_instance in vcd_vapp_vm.meta : vm_instance.computer_name
  ]
  #---
  #FRONT
  vm_ips_front = flatten([
    for vm in vcd_vapp_vm.front : [
      for network in vm.network : network.ip
    ]
  ])
  vm_names_front = [
    for vm_instance in vcd_vapp_vm.front : vm_instance.computer_name
  ]
  #---
  #BALANCER
  vm_ips_balancer   = vcd_vapp_vm.balancer.network[0].ip
  vm_names_balancer = vcd_vapp_vm.balancer.computer_name
  #---
  #MONITORING
  vm_ips_monitoring   = vcd_vapp_vm.monitoring.network[0].ip
  vm_names_monitoring = vcd_vapp_vm.monitoring.computer_name
  #---
  #IAM
  vm_ips_iam   = vcd_vapp_vm.iam.network[0].ip
  vm_names_iam = vcd_vapp_vm.iam.computer_name

  #ZIPMAP for key value
  storage = zipmap(local.vm_names_storage, local.vm_ips_storage)
  meta    = zipmap(local.vm_names_meta, local.vm_ips_meta)
  front   = zipmap(local.vm_names_front, local.vm_ips_front)
  #тут изначально получили строки, так как вм создаются в единичном экземпляре,поэтому насильно заводим в массив
  balancer   = zipmap([local.vm_names_balancer], [local.vm_ips_balancer])
  monitoring = zipmap([local.vm_names_monitoring], [local.vm_ips_monitoring])
  iam        = zipmap([local.vm_names_iam], [local.vm_ips_iam])
  #Создаём 1 общий объект
  combined_data = merge(
    local.storage,
    local.meta,
    local.front,
    local.balancer,
    local.monitoring,
    local.iam
  )
  #combined_array = concat(local.storage, local.meta, local.front, local.balancer, local.monitoring, local.iam)
}

#в Terraform используется для создания вывода, который предоставляет доступ к определенным значениям или переменным из вашей конфигурации Terraform после её выполнения. В данном случае, output "vm_ips" позволяет вам создать вывод с именем vm_ips и присвоить ему значение, которое содержится в переменной local.vm_ips.
#просто херь чтобы понимать что мы вытаскиваем
output "combined_data" {
  value = local.combined_data
}
output "vm_ips_storage" {
  value = local.vm_ips_storage
}

#ГЕНЕРИМ ФАЙЛИКИ
#Фрагмент resource "local_file" "hosts_cfg" в Terraform используется для создания файла на локальной системе на основе содержимого и шаблона.
#В данном случае, этот ресурс используется для создания файла hosts.cfg на основе шаблона hosts.tpl, подставляя значения из переменной local.vm_ips в шаблон.
resource "local_file" "hosts_cfg" {
  content = templatefile("${path.module}/inv.tpl",
    {
      vm_ips_storage    = local.vm_ips_storage
      vm_ips_meta       = local.vm_ips_meta
      vm_ips_front      = local.vm_ips_front
      vm_ips_monitoring = local.vm_ips_monitoring
      vm_ips_balancer   = local.vm_ips_balancer
      vm_ips_iam        = local.vm_ips_iam
    }
  )
  filename = "inv.cfg"
}

#ГЕНЕРИМ hosts
resource "local_file" "inv_cfg" {
  content = templatefile("${path.module}/hosts.tpl",
    {
      #это всё массивы данных с key-value
      array = local.combined_data
    }
  )
  filename = "hosts.cfg"
}

#ЗАПУСКАЕМ playbook
resource "null_resource" "ansible_provisioner" {

  triggers = {
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      timeout 2m ansible-playbook -i "${path.module}/inv.cfg" \
                       -u onlanta provision.yml
    EOT
  }
}
