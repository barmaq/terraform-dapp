# сохраняем ключ в локальные перменные
locals {
  ssh_key = var.ssh_public_key != "" ? var.ssh_public_key : file("~/.ssh/ycbarmaq.pub")
}
# зоны для переиспользвания
locals {
  zones = ["ru-central1-a", "ru-central1-b", "ru-central1-d"]
}
