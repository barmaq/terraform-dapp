# создаем файл инвентаря для ansible
resource "local_file" "inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    control_plane_internal_ips = yandex_compute_instance.kube-cp[*].network_interface[0].ip_address
    worker_node_internal_ips = yandex_compute_instance.kube-nodes[*].network_interface[0].ip_address
  })
  filename = "${path.module}/inventory.yml"
}

# В этом файле развертывается k8s кластер на основе Kubespray
# Важные нюансы - amsible ставить и запускать в вирт окружении venv, пути указывтаь абсолютные. предупреждение о отсутсвии отпечатков серверов в known_hosts можно побойти запуская ансибл с параметром -e 'ansible_ssh_common_args="-o StrictHostKeyChecking=no"'
# так же запускаем kubectl под sudo 


# Устанавливаем Ansible и запускаем развертывание на первом control plane узле
resource "null_resource" "deploy_k8s" {
  depends_on = [
    yandex_compute_instance.kube-cp,
    yandex_compute_instance.kube-nodes,
    local_file.inventory
  ]

  # Триггер для перезапуска при изменении инстансов
  triggers = {
    cluster_instance_ids = join(",", concat(
      [for inst in yandex_compute_instance.kube-cp : inst.id],
      [for inst in yandex_compute_instance.kube-nodes : inst.id]
    ))
  }

  # Копируем SSH ключ на первый control plane узел
  provisioner "file" {
    source      = var.ssh_private_key_path
    destination = "/home/ubuntu/.ssh/id_rsa"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = yandex_compute_instance.kube-cp[0].network_interface.0.nat_ip_address
    }
  }

  # Копируем inventory файл
  provisioner "file" {
    source      = "${path.module}/inventory.yml"
    destination = "/home/ubuntu/inventory.yml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = yandex_compute_instance.kube-cp[0].network_interface.0.nat_ip_address
    }
  }

  # Создаем конфигурацию для отключения проверки SSH host keys
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /home/ubuntu/.ssh",
      "echo 'Host *' > /home/ubuntu/.ssh/config",
      "echo '    StrictHostKeyChecking no' >> /home/ubuntu/.ssh/config",
      "echo '    UserKnownHostsFile=/dev/null' >> /home/ubuntu/.ssh/config",
      "chmod 600 /home/ubuntu/.ssh/config",
      
      # Создаем ansible.cfg
      "echo '[defaults]' > /home/ubuntu/ansible.cfg",
      "echo 'host_key_checking = False' >> /home/ubuntu/ansible.cfg",
      "echo 'interpreter_python = auto_silent' >> /home/ubuntu/ansible.cfg",
      "echo 'roles_path = /home/ubuntu/kubespray/roles:/home/ubuntu/kubespray/playbooks/roles' >> /home/ubuntu/ansible.cfg"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = yandex_compute_instance.kube-cp[0].network_interface.0.nat_ip_address
    }
  }

  # Устанавливаем Ansible и запускаем развертывание
  provisioner "remote-exec" {
    inline = [
      # Установка необходимых пакетов
      "sudo apt-get update",
      "sudo apt-get install -y python3-pip python3-venv python3-full git",
      
      # Создание и активация виртуального окружения
      "python3 -m venv /home/ubuntu/venv",
      ". /home/ubuntu/venv/bin/activate",
      
      # Установка Ansible в виртуальное окружение
      "/home/ubuntu/venv/bin/pip3 install ansible",
      
      # Настройка прав доступа для SSH ключа
      "chmod 600 /home/ubuntu/.ssh/id_rsa",
      
      # Клонирование Kubespray
      "rm -rf /home/ubuntu/kubespray",
      "git clone https://github.com/kubernetes-sigs/kubespray.git /home/ubuntu/kubespray",
      "cd /home/ubuntu/kubespray",
      
      # Установка зависимостей Kubespray
      "/home/ubuntu/venv/bin/pip3 install -r requirements.txt",
      
      # Копирование примера inventory
      "cp -rfp inventory/sample inventory/mycluster",
      
      # Проверка подключения ко всем хостам
      "cd /home/ubuntu/kubespray && ANSIBLE_CONFIG=/home/ubuntu/ansible.cfg /home/ubuntu/venv/bin/ansible all -m ping -i /home/ubuntu/inventory.yml",
      
      # Запуск Kubespray
      "cd /home/ubuntu/kubespray && ANSIBLE_CONFIG=/home/ubuntu/ansible.cfg /home/ubuntu/venv/bin/ansible-playbook -i /home/ubuntu/inventory.yml --private-key=/home/ubuntu/.ssh/id_rsa -e ansible_user=ubuntu -b cluster.yml",
      
      # Копируем kubeconfig во временный файл с правильными правами доступа
      "sudo cp /etc/kubernetes/admin.conf /home/ubuntu/admin.conf",
      "sudo chown ubuntu:ubuntu /home/ubuntu/admin.conf",
      
      # Удаляем приватный ключ после всех работ
      "rm -f /home/ubuntu/.ssh/id_rsa"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file(var.ssh_private_key_path)
      host        = yandex_compute_instance.kube-cp[0].network_interface.0.nat_ip_address
    }
  }

  # Копируем kubeconfig локально
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ${var.ssh_private_key_path} ubuntu@${yandex_compute_instance.kube-cp[0].network_interface.0.nat_ip_address}:/home/ubuntu/admin.conf ${path.module}/admin.conf"
  }
}

# Читаем содержимое kubeconfig файла
data "local_file" "kubeconfig" {
  depends_on = [null_resource.deploy_k8s]
  filename   = "${path.module}/admin.conf"
} 