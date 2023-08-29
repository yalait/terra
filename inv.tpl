[all]
%{ for ip in vm_ips_storage ~}
${ip}
%{ endfor ~}
%{ for ip in vm_ips_meta ~}
${ip}
%{ endfor ~}
%{ for ip in vm_ips_front ~}
${ip}
%{ endfor ~}
${vm_ips_monitoring}
${vm_ips_balancer}
[stor]
%{ for ip in vm_ips_storage ~}
${ip}
%{ endfor ~}
[meta]
%{ for ip in vm_ips_meta ~}
${ip}
%{ endfor ~}
[front]
%{ for ip in vm_ips_front ~}
${ip}
%{ endfor ~}
[monitoring]
${vm_ips_monitoring}
${vm_ips_balancer}
[iam]
${vm_ips_iam}
