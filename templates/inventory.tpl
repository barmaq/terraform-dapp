# This inventory describe a HA typology with stacked etcd (== same nodes as control plane)
# and worker nodes
# See https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html

# Configure 'ip' variable to bind kubernetes services on a different ip than the default iface
# We should set etcd_member_name for etcd cluster. The node that are not etcd members do not need to set the value,
# or can set the empty string value.
[kube_control_plane]
%{ for index, ip in control_plane_internal_ips ~}
k8s-master-${index + 1} ansible_host=${ip}
%{ endfor ~}

[etcd:children]
kube_control_plane

[kube_node]
%{ for index, ip in worker_node_internal_ips ~}
k8s-worker-${index + 1} ansible_host=${ip}
%{ endfor ~}

[k8s_cluster:children]
kube_control_plane
kube_node

[all:vars]
ansible_user=ubuntu
ansible_become=yes 