[TestVm]
%{ for ip in vm_ips ~}
${ip}
%{ endfor ~}