%{ for key, value in array ~}
${value} ${key} ${key}.vk-test.local
%{ endfor ~}
