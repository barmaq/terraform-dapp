# создаем мастер-узлы
resource "yandex_compute_instance" "kube-cp" {
  count       = var.kube-k8s_cp_count
  name        = "${var.default_vm.k8s_cp.vm_name}-${count.index + 1}"
  hostname    = "${var.default_vm.k8s_cp.vm_name}-${count.index + 1}"
  zone        = element(local.zones, count.index)
  platform_id = var.default_vm.k8s_cp.platform_id

  resources {
    cores         = var.default_vm.k8s_cp.cpu
    memory        = var.default_vm.k8s_cp.ram
    core_fraction = var.default_vm.k8s_cp.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.image.image_id
    }
  }

  scheduling_policy {
    preemptible = var.default_vm.k8s_cp.preemptible
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet[element(local.zones, count.index)].id
    nat       = var.default_vm.k8s_cp.nat
  }

  metadata = {
    serial-port-enable = var.default_vm.k8s_cp.serial-port-enable
    ssh-keys           = "ubuntu:${local.ssh_key}"
  }
}
