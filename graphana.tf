# добавляем установку kube-prometheus-stack 

# Установка Prometheus и Grafana через Helm
resource "null_resource" "install_monitoring" {
  depends_on = [null_resource.deploy_k8s]

  # Копируем kubeconfig локально для использования kubectl и helm
  provisioner "remote-exec" {
    inline = [
      # Установка Helm
      "curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash",
      
      # Добавляем репозиторий Prometheus
      "sudo helm repo add prometheus-community https://prometheus-community.github.io/helm-charts",
      "sudo helm repo update",
      
      # Создаем namespace для мониторинга
      "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf create namespace monitoring",
      
      # Установка Prometheus stack с пользовательским паролем
      "sudo helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring --kubeconfig=/etc/kubernetes/admin.conf --set grafana.adminPassword='${var.grafana_admin_password}'",
      
      # Создаем NodePort сервис для доступа к Grafana извне
      "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf patch svc prometheus-grafana -n monitoring -p '{\"spec\": {\"type\": \"NodePort\", \"ports\": [{\"nodePort\": 30000, \"port\": 80, \"protocol\": \"TCP\", \"targetPort\": 3000}]}}'",
      
      # Выводим информацию о доступе. Grafana стартует полностью через 2-4 минуты
      "echo 'Grafana will be available at NodePort 30000'"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = yandex_compute_instance.kube-cp[0].network_interface.0.nat_ip_address
    }
  }
} 