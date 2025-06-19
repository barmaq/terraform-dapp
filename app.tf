# Создание манифестов из шаблонов
data "template_file" "deployment" {
  template = file("${path.module}/k8s-templates/deployment.yaml.tpl")

  vars = {
    app_name        = var.app_config.name
    namespace       = var.app_config.namespace
    replicas        = var.app_config.replicas
    image           = var.app_config.image
    container_port  = var.app_config.container_port
    cpu_request     = var.app_config.resources.requests.cpu
    memory_request  = var.app_config.resources.requests.memory
    cpu_limit       = var.app_config.resources.limits.cpu
    memory_limit    = var.app_config.resources.limits.memory
  }
}

data "template_file" "service" {
  template = file("${path.module}/k8s-templates/service.yaml.tpl")

  vars = {
    app_name       = var.app_config.name
    namespace      = var.app_config.namespace
    service_type   = var.app_config.service_type
    service_port   = var.app_config.service_port
    container_port = var.app_config.container_port
    node_port      = var.app_config.node_port
  }
}

# Установка приложения barmaq-dapp
resource "null_resource" "deploy_app" {
  depends_on = [null_resource.deploy_k8s]

  # Триггер для перезапуска при изменении конфигурации
  triggers = {
    deployment_template = data.template_file.deployment.rendered
    service_template    = data.template_file.service.rendered
  }

  provisioner "remote-exec" {
    inline = [
      # Создаем namespace для приложения
      "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf create namespace ${var.app_config.namespace} || true",
      
      # Создаем файлы манифестов из шаблонов
      "cat << 'EOF' > /tmp/deployment.yaml\n${data.template_file.deployment.rendered}\nEOF",
      "cat << 'EOF' > /tmp/service.yaml\n${data.template_file.service.rendered}\nEOF",

      # Применяем манифесты
      "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f /tmp/deployment.yaml",
      "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf apply -f /tmp/service.yaml",
      
      # Ждем, пока деплоймент станет доступен
      "sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf wait --namespace ${var.app_config.namespace} --for=condition=available deployment/${var.app_config.name} --timeout=300s"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = yandex_compute_instance.kube-cp[0].network_interface.0.nat_ip_address
    }
  }
} 