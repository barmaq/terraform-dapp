# =====================
# Конфигурация Kubernetes
# Содержит файлы kubeconfig для доступа к кластеру
# =====================
output "kubeconfig" {
  value     = data.local_file.kubeconfig.content
  sensitive = true
  description = "Raw kubeconfig content!"
}

output "kubeconfig_external" {
  value = replace(
    data.local_file.kubeconfig.content,
    "server: https://127.0.0.1:",
    "server: https://${yandex_compute_instance.kube-cp[0].network_interface[0].nat_ip_address}:"
  )
  sensitive = true
  description = "Kubeconfig with external IP address for remote access"
}

# =====================
# Информация о Control Plane
# IP-адреса мастер-узлов для управления кластером
# =====================
output "control_plane_external_ips" {
  value = yandex_compute_instance.kube-cp[*].network_interface[0].nat_ip_address
  description = "Public IP addresses of control plane nodes"
}

output "control_plane_internal_ips" {
  value = yandex_compute_instance.kube-cp[*].network_interface[0].ip_address
  description = "Internal IP addresses of control plane nodes"
}

# =====================
# Информация о Worker Nodes
# IP-адреса рабочих узлов для развертывания приложений
# =====================
output "worker_node_external_ips" {
  value = yandex_compute_instance.kube-nodes[*].network_interface[0].nat_ip_address
  description = "Public IP addresses of worker nodes"
}

output "worker_node_internal_ips" {
  value = yandex_compute_instance.kube-nodes[*].network_interface[0].ip_address
  description = "Internal IP addresses of worker nodes"
}

# =====================
# Точки доступа к приложению
# URL-адреса для доступа к приложению через различные точки входа
# =====================
output "app_control_plane_url" {
  value = "http://${yandex_compute_instance.kube-cp[0].network_interface.0.nat_ip_address}:${var.app_config.node_port}"
  description = "URL for accessing the application through control plane"
}

output "app_worker_urls" {
  value = [
    for node in yandex_compute_instance.kube-nodes :
    "http://${node.network_interface[0].nat_ip_address}:${var.app_config.node_port}"
  ]
  description = "URLs for accessing the application through worker nodes"
}

output "app_alb_url" {
  value = "https://app.barmaq.ru"
  description = "URL for accessing the application through load balancer (HTTPS)"
}

# =====================
# Панель мониторинга
# Информация для доступа к Grafana и учетные данные
# =====================
output "grafana_url" {
  value = "http://${yandex_compute_instance.kube-cp[0].network_interface.0.nat_ip_address}:30000"
  description = "URL for accessing Grafana"
}

output "grafana_info" {
  value = "Login: admin"
  description = "Grafana login information"
}

output "grafana_password" {
  value     = var.grafana_admin_password
  sensitive = true
  description = "Grafana admin password"
}

# =====================
# DNS Конфигурация
# Информация о домене и DNS-зоне приложения
# =====================
# output "app_domain" {
#   value = var.app_config.domain
#   description = "Domain name for the application"
# }

# output "dns_zone_name" {
#   value = yandex_dns_zone.main_zone.name
#   description = "Name of the DNS zone"
# }

# output "app_dns_record" {
#   value = yandex_dns_recordset.app_record.name
#   description = "DNS A record for the application"
# }

# Создаем локальную переменную с содержимым inventory
locals {
  inventory_template = templatefile("${path.module}/templates/inventory.tpl", {
    control_plane_external_ips = yandex_compute_instance.kube-cp[*].network_interface[0].nat_ip_address
    control_plane_internal_ips = yandex_compute_instance.kube-cp[*].network_interface[0].ip_address
    worker_node_external_ips = yandex_compute_instance.kube-nodes[*].network_interface[0].nat_ip_address
    worker_node_internal_ips = yandex_compute_instance.kube-nodes[*].network_interface[0].ip_address
  })
}
