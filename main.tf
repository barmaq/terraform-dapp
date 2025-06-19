# создаем vpc
resource "yandex_vpc_network" "develop" {
  name = var.vpc_name
}

# образ для создания виртуальных машин
data "yandex_compute_image" "image" {
  family = var.default_vm.standart.image_family
}

# создаем подсети
resource "yandex_vpc_subnet" "subnet" {
  for_each = {
    for k,v in var.subnets :
      v.zone => v
  }
  name           = "subnet-${each.value.zone}"
  zone           = "${each.value.zone}"
  network_id     = yandex_vpc_network.develop.id
  v4_cidr_blocks = ["${each.value.cidr}"]
}
