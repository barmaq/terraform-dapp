# создаем рабочие узлы

resource "yandex_compute_instance" "kube-nodes" {
  count       = var.kube-k8s_nodes_count
  name        = "${var.default_vm.k8s_nodes.vm_name}-${count.index + 1}"
  hostname    = "${var.default_vm.k8s_nodes.vm_name}-${count.index + 1}"
  zone        = element(local.zones, count.index)
  platform_id = var.default_vm.k8s_nodes.platform_id

  resources {
    cores         = var.default_vm.k8s_nodes.cpu
    memory        = var.default_vm.k8s_nodes.ram
    core_fraction = var.default_vm.k8s_nodes.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.image.image_id
    }
  }

  scheduling_policy {
    preemptible = var.default_vm.k8s_nodes.preemptible
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet[element(local.zones, count.index)].id
    nat       = var.default_vm.k8s_nodes.nat
  }

  metadata = {
    serial-port-enable = var.default_vm.k8s_nodes.serial-port-enable
    ssh-keys           = "ubuntu:${local.ssh_key}"
  }
}
